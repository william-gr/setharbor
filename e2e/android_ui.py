"""Black-box Android UI driver using only adb and the Python standard library."""
import json, os, re, shlex, subprocess, time, xml.etree.ElementTree as ET
from pathlib import Path

PACKAGE = 'com.william.treino.e2e'
ACTIVITY = 'com.william.treino.MainActivity'

class AndroidUI:
    def __init__(self, adb='adb', serial=None):
        self.prefix = [adb] + (['-s', serial] if serial else [])
        self.last_xml = ''
        self.last_adb_error = None

    def adb(self, *args, timeout=90, check=True):
        try:
            return subprocess.run(self.prefix + list(args), capture_output=True, text=True,
                                  timeout=timeout, check=check).stdout.strip()
        except subprocess.CalledProcessError as err:
            self.last_adb_error={'command':list(args),'returncode':err.returncode,
                                 'stdout':err.stdout,'stderr':err.stderr}
            raise

    def shell(self, command):
        return self.adb('shell', command)

    def launch(self):
        self.shell('input keyevent 82')
        self.shell('wm dismiss-keyguard')
        self.shell(f'am start -W -n {PACKAGE}/{ACTIVITY}')
        self.wait(lambda: self.has(text='SetHarbor'), 30)

    def reset(self):
        # Never clear the user's personal package: E2E has a different applicationId.
        self.last_adb_error=None
        self.shell(f'am force-stop {PACKAGE}')
        try:
            cleared=self.shell(f'pm clear {PACKAGE}')
        except subprocess.CalledProcessError as err:
            detail=((err.stdout or '')+' '+(err.stderr or '')).lower()
            if not any(message in detail for message in
                       ['error: closed','device offline','transport error',
                        'connection reset','protocol fault']): raise
            # Only retry idempotent setup after a diagnosed ADB transport failure.
            self.adb('wait-for-device',timeout=30)
            cleared=self.shell(f'pm clear {PACKAGE}')
        if cleared!='Success': raise AssertionError(f'E2E data reset failed: {cleared}')
        self.launch()
        self.choose_day('Segunda')

    def restart(self):
        self.shell(f'am force-stop {PACKAGE}')
        self.launch()

    def dump(self):
        # Failed dumps can leave an older file behind, especially on a ticking UI.
        for _ in range(3):
            self.shell('rm -f /sdcard/e2e-window.xml')
            output=self.shell('uiautomator dump /sdcard/e2e-window.xml')
            if 'dumped to' in output:
                self.last_xml=self.shell('cat /sdcard/e2e-window.xml')
                return ET.fromstring(self.last_xml)
            time.sleep(.3)
        raise AssertionError(f'Cannot obtain fresh UI hierarchy: {output}')

    def nodes(self, **attrs):
        def match(node):
            bounds=[int(x) for x in re.findall(r'\d+',node.get('bounds',''))]
            if len(bounds)!=4 or bounds[2]<=bounds[0] or bounds[3]<=bounds[1]: return False
            for key,value in attrs.items():
                actual=node.get({'desc':'content-desc','cls':'class'}.get(key,key),'')
                # Native Android dialog buttons may render labels in ALL CAPS.
                if key=='text' and node.get('class')=='android.widget.Button':
                    if actual.casefold()!=value.casefold(): return False
                elif key=='package' and value=='com.android.documentsui':
                    if actual not in {'com.android.documentsui','com.google.android.documentsui'}: return False
                elif actual!=value: return False
            return True
        return [n for n in self.dump().iter('node') if match(n)]

    def has(self, **attrs):
        try: return bool(self.nodes(**attrs))
        except (ET.ParseError, subprocess.SubprocessError): return False

    @staticmethod
    def wait(predicate, timeout=20):
        limit=time.monotonic()+timeout*float(os.environ.get("E2E_TIMEOUT_SCALE","1"))
        while time.monotonic()<limit:
            value=predicate()
            if value: return value
            time.sleep(.3)
        raise AssertionError(f'Condition not met in {timeout}s')

    def tap_node(self, node):
        bounds=[int(x) for x in re.findall(r'\d+',node.get('bounds',''))]
        if len(bounds)!=4 or bounds[2]<=bounds[0] or bounds[3]<=bounds[1]:
            raise AssertionError('Node has no visible bounds')
        self.shell(f'input tap {(bounds[0]+bounds[2])//2} {(bounds[1]+bounds[3])//2}')
        # ADB returning does not mean Android has dispatched the tap/layout yet.
        time.sleep(.3)

    def tap(self, scroll=False, **attrs):
        matches=self.nodes(**attrs)
        if not matches and scroll:
            self.scroll_to(**attrs); matches=self.nodes(**attrs)
        if not matches: raise AssertionError(f'Element not found: {attrs}')
        # Dialog button and underlying button can have the same text; last is on top.
        self.tap_node(matches[-1])

    def size(self):
        values=re.findall(r'(\d+)x(\d+)',self.shell('wm size'))
        return tuple(map(int,values[-1]))

    def swipe(self, forward=True):
        width,height=self.size(); x=width//2
        a,b=(int(height*.80),int(height*.32)) if forward else (int(height*.32),int(height*.80))
        self.shell(f'input swipe {x} {a} {x} {b} 350')

    def scroll_to(self, **attrs):
        previous=''
        for _ in range(25):
            if self.has(**attrs): return
            current=self.last_xml
            if current==previous: break
            previous=current; self.swipe()
        raise AssertionError(f'Cannot scroll to {attrs}')

    def top(self):
        if self.has(desc='Dia do treino'): return
        previous=''
        for _ in range(25):
            self.dump()
            if self.last_xml==previous: break
            previous=self.last_xml
            self.swipe(False)

    def fill(self, value, **attrs):
        self.scroll_to(**attrs)
        node=self.nodes(**attrs)[-1]
        self.tap_node(node)
        focused=self.wait(lambda: [n for n in self.nodes(**attrs)
                                  if n.get('focused')=='true'])[0]
        # Empty EditTexts expose their hint as text in UI Automator.
        old=focused.get('text','')
        self.shell('input keyevent 123')
        if old: self.shell('input keyevent '+' '.join(['67']*len(old)))
        if value: self.shell('input text '+shlex.quote(str(value)))
        if value:
            self.wait(lambda: any(n.get('text')==str(value) for n in self.nodes(**attrs)))
        self.shell('input keyevent 4')
        time.sleep(.3)

    def choose_day(self, day):
        self.top(); self.tap(desc='Dia do treino'); self.tap(text=day)

    def phase(self, phase='Normal · volume completo · RIR 1–2'):
        self.top(); self.tap(desc='Modo do treino'); self.tap(text=phase)

    def set_series(self, exercise='legacy-0-0', index=1, kg='40', reps='8'):
        self.fill(kg, desc=f'Carga · {exercise} · {index}')
        self.fill(reps, desc=f'Repetições · {exercise} · {index}')

    def check_series(self, name='Supino reto barra', index=1):
        self.tap(scroll=True, desc=f'Série {index} concluída em {name}')

    def finish(self, save=True):
        self.tap(scroll=True,text='Concluir e salvar treino')
        self.wait(lambda:self.has(text='Salvar treino?'))
        self.tap(text='Salvar' if save else 'Voltar')

    def history(self):
        self.tap(scroll=True,text='Histórico de treinos')
        self.wait(lambda:self.has(text='Histórico'))

    def push_fixture(self, path, name=None):
        name=name or Path(path).name
        self.shell('mkdir -p /sdcard/Download')
        self.adb('push',str(path),'/sdcard/Download/'+name)
        return name

    def select_document(self, filename):
        # Exercise the real system DocumentsUI, not an injected activity result.
        self.wait(lambda: self.has(package='com.android.documentsui'),30)
        if not self.has(text=filename):
            for desc in ['Show roots','Mostrar raízes','Open navigation drawer','Show navigation']:
                if self.has(desc=desc): self.tap(desc=desc); break
            for label in ['Downloads','Download']:
                if self.has(text=label): self.tap(text=label); break
        # Search the real picker so recycled list/grid accessibility rows cannot
        # hide a document after scrolling. This also handles crowded Downloads.
        for desc in ['Search','Pesquisar']:
            if self.has(desc=desc):
                self.tap(desc=desc)
                break
        else: raise AssertionError('Document picker search control not found')
        search=self.wait(lambda: [n for n in self.nodes()
                                 if n.get('resource-id','').endswith(':id/search_src_text')])[0]
        self.fill(filename,**{'resource-id':search.get('resource-id')})
        target={'text':filename,'resource-id':'android:id/title'}
        self.wait(lambda: self.has(**target),30)
        self.tap(**target)

    def import_plan(self, path):
        name=self.push_fixture(path)
        self.tap(scroll=True,text='Importar ficha de treino')
        self.select_document(name)

    def export_backup(self, filename='e2e-backup.json'):
        self.shell('rm -f /sdcard/Download/'+shlex.quote(filename))
        self.tap(scroll=True,text='Exportar backup')
        self.wait(lambda:bool(self.nodes(cls='android.widget.EditText')),30)
        # Ensure the destination is Downloads, then enter a unique backup name.
        for desc in ['Show roots','Open navigation drawer','Show navigation']:
            if self.has(desc=desc): self.tap(desc=desc); break
        for label in ['Downloads','Download']:
            if self.has(text=label): self.tap(text=label); break
        self.fill(filename, cls='android.widget.EditText')
        for label in ['SAVE','Save','SALVAR','Salvar']:
            if self.has(text=label): self.tap(text=label); break
        self.wait(lambda:self.has(text='SetHarbor'))
        raw=self.shell('cat /sdcard/Download/'+shlex.quote(filename))
        return json.loads(raw)

    def restore_backup(self, path):
        name=self.push_fixture(path)
        self.tap(scroll=True,text='Restaurar backup')
        self.select_document(name)

    def configure_url(self,url):
        self.tap(scroll=True,text='Atualização online')
        self.fill(url,cls='android.widget.EditText')
        self.tap(text='Salvar e verificar')

    def artifacts(self, directory):
        directory=Path(directory); directory.mkdir(parents=True,exist_ok=True)
        (directory/'window.xml').write_text(self.last_xml)
        if self.last_adb_error:
            (directory/'adb-error.json').write_text(json.dumps(self.last_adb_error,indent=2))
        try:(directory/'logcat.txt').write_text(self.adb('logcat','-d','-t','1000',check=False))
        except subprocess.SubprocessError as err:(directory/'artifact-error.txt').write_text(str(err))
        try:
            png=subprocess.run(self.prefix+['exec-out','screencap','-p'],capture_output=True,timeout=30).stdout
            (directory/'screen.png').write_bytes(png)
        except subprocess.SubprocessError: pass
