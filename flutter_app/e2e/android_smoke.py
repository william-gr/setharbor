"""Real OS migration/IO/link smoke. Disposable emulator and .e2e package ONLY."""
import base64
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'e2e'))
from android_ui import AndroidUI, PACKAGE

class FlutterUI(AndroidUI):
    def nodes(self, **attrs):
        text=attrs.pop('text',None)
        nodes=super().nodes(**attrs)
        if text is None:return nodes
        return [n for n in nodes if n.get('text','').casefold()==text.casefold() or text in n.get('content-desc','').split('\n')]

ui=FlutterUI(os.environ.get('ADB','adb'),os.environ.get('ANDROID_SERIAL','emulator-5554'))
ARTIFACTS=ROOT/'e2e/artifacts/flutter-os'

def write_private(path, text):
    subprocess.run(ui.prefix+['shell',f'run-as {PACKAGE} sh -c '+shlex.quote(f'cat > {path}')],input=text,text=True,check=True,capture_output=True)

def disk():
    return json.loads(ui.shell(f'run-as {PACKAGE} cat files/training-flutter.json'))

def startup_link(plan):
    payload=base64.urlsafe_b64encode(json.dumps(plan,ensure_ascii=False).encode()).decode().rstrip('=')
    url='setharbor://workout#v1.'+payload
    ui.shell('am start -W -a android.intent.action.VIEW -d '+shlex.quote(url)+' -n '+PACKAGE+'/com.william.treino.MainActivity')

def run():
    assert ui.shell('getprop ro.kernel.qemu')=='1','Use a disposable emulator, never a phone'
    native=Path(os.environ.get('LEGACY_APK',str(ROOT/'app/build/outputs/apk/e2e/app-e2e.apk')))
    flutter=Path(os.environ.get('FLUTTER_APK',str(ROOT/'flutter_app/build/app/outputs/flutter-apk/app-e2e-debug.apk')))
    assert native.is_file() and flutter.is_file()
    # Downgrade is restricted to the disposable test package. No uninstall fallback.
    ui.adb('install','-r','-d',str(native),timeout=180)
    assert ui.shell(f'pm clear {PACKAGE}')=='Success'
    original=json.loads((ROOT/'app/src/main/assets/default-plan.json').read_text())
    catalog=json.loads((ROOT/'app/src/main/assets/exercise-catalog.json').read_text())['exercises']
    planned=original['days'][1]['exercises'][0]
    current=next(ex for ex in catalog if ex['id']==planned['catalogId'])
    target=next(ex for ex in catalog if ex['id']!=current['id'] and all(ex[k]==current[k] for k in ['group','substitutionFamily','movementPattern','mechanic']) and ex['loadUnit']!='band' and ex['mechanic']!='isometric')
    legacy_history=[{'date':'01/10/2026 10:00','day':0,'phase':2,'sets':{'0_0done':True,'0_0kg':'30','0_0reps':'8'}}, {'date':'02/10/2026 10:00','day':2,'phase':1,'sets':{'0_0done':True,'0_0kg':'','0_0reps':''},'plan':original,'extra':True,'workoutLabel':'Treino C'}]
    prefs={'history':json.dumps(legacy_history,ensure_ascii=False),'plan':json.dumps(original,ensure_ascii=False),'phase':2,'day':1,'nextWorkoutId':json.dumps(['day-1']), 'draft1':json.dumps({'0_0kg':'13,5','0_0reps':'','0_0done':True,'exerciseOverrides':{planned['id']:target['id']}})}
    tree=ET.Element('map')
    for key,value in prefs.items():
        if isinstance(value,int):ET.SubElement(tree,'int',name=key,value=str(value))
        else:ET.SubElement(tree,'string',name=key).text=value
    ui.shell(f'run-as {PACKAGE} mkdir -p shared_prefs')
    write_private('shared_prefs/training.xml',ET.tostring(tree,encoding='unicode'))
    ui.launch();assert ui.has(text='Próximo: Treino B')
    ui.shell(f'am force-stop {PACKAGE}')
    native_xml=ui.shell(f'run-as {PACKAGE} cat shared_prefs/training.xml')
    ui.adb('install','-r',str(flutter),timeout=180)
    ui.launch();ui.wait(lambda:ui.has(text='Próximo: Treino B'),45)
    state=disk();assert len(state['history'])==2 and state['phase']==2 and state['day']==1
    assert state['nextWorkoutId']=='day-1' and state['draft1']['exerciseOverrides'][planned['id']]==target['id']
    assert state['draft1']['0_0kg']=='13,5' and state['history'][0]['plan']==original
    assert ui.shell(f'run-as {PACKAGE} cat shared_prefs/training.xml')==native_xml
    ui.artifacts(ARTIFACTS/'01-upgrade');print('PASS native → Flutter upgrade preserves history/draft/override/sequence and original prefs',flush=True)

    # Actual filesystem failure, no mocked save endpoint.
    before=disk()
    ui.tap(scroll=True,text='Concluir e salvar treino');ui.wait(lambda:ui.has(text='Salvar treino?'))
    try:
        ui.shell(f'run-as {PACKAGE} chmod 500 files')
        ui.tap(text='Salvar');ui.wait(lambda:ui.has(text='Falha ao gravar. Seu treino continua aberto.'))
        assert disk()==before
        ui.artifacts(ARTIFACTS/'02-failed-commit')
    finally:ui.shell(f'run-as {PACKAGE} chmod 700 files')
    ui.restart();assert disk()==before
    ui.tap(scroll=True,text='Concluir e salvar treino');ui.tap(text='Salvar')
    ui.wait(lambda:disk()['nextWorkoutId']=='day-2')
    assert len(disk()['history'])==3 and disk()['draft1']=={}
    assert disk()['history'][-1]['plan']['days'][1]['exercises'][0]['catalogId']==target['id']
    print('PASS real disk failure + restart rollback + successful retry',flush=True)

    backup=ui.export_backup('flutter-os-backup.json')
    assert backup['version']==4 and backup['nextWorkoutId']=='day-2' and len(backup['history'])==3 and 'planUrl' not in backup
    ui.artifacts(ARTIFACTS/'03-export')
    print('PASS real Android document export',flush=True)
    revised=json.loads((ROOT/'e2e/fixtures/link-three-day.json').read_text())
    startup_link(revised);ui.wait(lambda:ui.has(text='Aplicar treino do link?'))
    assert disk()['plan']['title']==original['title']
    ui.tap(text='Cancelar');assert disk()['plan']['title']==original['title']
    ui.shell(f'am force-stop {PACKAGE}');startup_link(revised)
    ui.wait(lambda:ui.has(text='Aplicar treino do link?'));ui.tap(text='Aplicar treino')
    ui.wait(lambda:disk()['plan']['title']==revised['title']);assert len(disk()['history'])==3
    ui.artifacts(ARTIFACTS/'04-cold-warm-links')
    print('PASS cold/warm native links preview, cancel and apply preserve history',flush=True)
    ui.tap(scroll=True,text='Restaurar backup');ui.select_document('flutter-os-backup.json')
    ui.wait(lambda:ui.has(text='Restaurar backup?'));ui.tap(text='Restaurar')
    ui.wait(lambda:disk()['plan']['title']==original['title']);assert disk()['nextWorkoutId']=='day-2'
    ui.artifacts(ARTIFACTS/'05-restore')
    print('PASS real Android document restore and cursor roundtrip',flush=True)
    # Import via OS picker, including preview, independent of deep links.
    ui.import_plan(ROOT/'e2e/fixtures/link-three-day.json')
    ui.wait(lambda:ui.has(text='Importar ficha?'));ui.tap(text='Importar')
    ui.wait(lambda:disk()['plan']['title']==revised['title'])
    print('PASS real Android plan import',flush=True)
    ui.tap(scroll=True,text='Planejar com ChatGPT')
    ui.wait(lambda:any(n.get('package') in {'android','com.android.intentresolver'} and ('chooser' in n.get('resource-id','').lower() or 'resolver' in n.get('resource-id','').lower()) for n in ui.dump().iter('node')),30)
    ui.artifacts(ARTIFACTS/'06-share');ui.shell('input keyevent 4')
    print('PASS native sharing sheet',flush=True)
    return {'migration':True,'diskRollback':True,'documents':True,'links':True,'share':True}

if __name__=='__main__':
    ARTIFACTS.mkdir(parents=True,exist_ok=True)
    try:
        result=run();(ARTIFACTS/'results.json').write_text(json.dumps(result,indent=2))
    except BaseException:
        ui.artifacts(ARTIFACTS/'failure');raise
