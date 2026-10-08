"""End-to-end tests against an installed Android app, through its real UI.

Run on an emulator: E2E_APK=app/build/outputs/apk/e2e/app-e2e.apk \
  python3 -m unittest discover -s e2e -p 'test_*.py' -v
No mocks of Android Activities, SharedPreferences or document picker are used.
"""
import http.server, json, os, ssl, tempfile, threading, time, unittest
from pathlib import Path
from android_ui import AndroidUI, PACKAGE

HERE=Path(__file__).resolve().parent
FIXTURES=HERE/'fixtures'
ARTIFACTS=Path(os.environ.get('E2E_ARTIFACTS',str(HERE/'artifacts')))

class FixtureHandler(http.server.BaseHTTPRequestHandler):
    requests=[]
    def do_GET(self):
        type(self).requests.append(self.path)
        if self.path=='/fail': self.send_error(503); return
        if self.path=='/redirect':
            self.send_response(302); self.send_header('Location','/updated.json'); self.end_headers(); return
        filename=self.path.lstrip('/')
        if filename not in {'original.json','updated.json','invalid.json','malformed.json'}:
            self.send_error(404); return
        content=(FIXTURES/filename).read_bytes()
        self.send_response(200); self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(content))); self.end_headers(); self.wfile.write(content)
    def log_message(self,*args): pass

class WorkoutAppE2E(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.results=[]
        cls.ui=AndroidUI(os.environ.get('ADB','adb'),os.environ.get('ANDROID_SERIAL'))
        if cls.ui.shell('getprop ro.kernel.qemu')!='1':
            raise RuntimeError('Use an emulator. Tests never clear data on a physical phone.')
        apk=Path(os.environ.get('E2E_APK','app/build/outputs/apk/e2e/app-e2e.apk'))
        if not apk.is_file(): raise RuntimeError(f'Build assembleE2e first: APK missing: {apk}')
        cls.ui.adb('install','-r',str(apk),timeout=240)
        cls.server=http.server.ThreadingHTTPServer(('127.0.0.1',0),FixtureHandler)
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(FIXTURES/'tls-cert.pem',FIXTURES/'tls-key.pem')
        cls.server.socket=tls.wrap_socket(cls.server.socket,server_side=True)
        cls.port=cls.server.server_port
        cls.ui.adb('reverse',f'tcp:{cls.port}',f'tcp:{cls.port}')
        threading.Thread(target=cls.server.serve_forever,daemon=True).start()
        cls.url=f'https://localhost:{cls.port}'

    @classmethod
    def tearDownClass(cls):
        output=ARTIFACTS;output.mkdir(parents=True,exist_ok=True)
        (output/'scenario-results.json').write_text(json.dumps(cls.results,ensure_ascii=False,indent=2))
        cls.server.shutdown();cls.server.server_close()
        cls.ui.adb('reverse','--remove',f'tcp:{cls.port}',check=False)

    def setUp(self):
        FixtureHandler.requests=[]
        self.temp=tempfile.TemporaryDirectory()
        try:self.ui.reset()
        except Exception:
            self.ui.artifacts(ARTIFACTS/self._testMethodName)
            self.temp.cleanup()
            raise

    def tearDown(self):
        result=self._outcome.result
        failed=any(test is self for test,_ in result.failures+result.errors)
        type(self).results.append({'test':self._testMethodName,'status':'failed' if failed else 'passed'})
        self.ui.artifacts(ARTIFACTS/self._testMethodName)
        self.temp.cleanup()

    def save_session(self):
        self.ui.set_series();self.ui.check_series();self.ui.finish()

    def plan_import(self):
        self.ui.import_plan(FIXTURES/'updated.json')
        self.ui.wait(lambda:self.ui.has(text='Importar ficha?'))
        self.ui.tap(text='Importar')
        self.ui.wait(lambda:self.ui.has(text='Ficha E2E revisada'))

    def json_file(self,name,payload):
        path=Path(self.temp.name)/name;path.write_text(json.dumps(payload,ensure_ascii=False));return path

    def test_01_first_launch_all_five_days(self):
        for day,exercise in [('Segunda','Supino reto barra'),('Terça','Puxada alta neutra'),('Quarta','Desenvolvimento máquina / halteres'),('Quinta','Supino inclinado Smith / máquina'),('Sexta','Rosca Scott')]:
            self.ui.choose_day(day);self.ui.scroll_to(text=exercise);self.assertTrue(self.ui.has(text=exercise))

    def test_02_readaptation_and_full_volume(self):
        self.assertFalse(self.ui.has(desc='Carga · legacy-0-0 · 3'))
        self.ui.phase();self.ui.scroll_to(desc='Carga · legacy-0-0 · 3')
        self.assertTrue(self.ui.has(desc='Carga · legacy-0-0 · 3'))
        self.ui.phase('Semana 2 · volume completo · RIR 2')
        self.ui.scroll_to(desc='Carga · legacy-0-0 · 3');self.assertTrue(self.ui.has(desc='Carga · legacy-0-0 · 3'))

    def test_03_draft_survives_process_restart(self):
        self.ui.set_series(kg='42.5',reps='9');self.ui.restart()
        self.ui.scroll_to(desc='Carga · legacy-0-0 · 1')
        self.assertEqual('42.5',self.ui.nodes(desc='Carga · legacy-0-0 · 1')[-1].get('text'))
        self.assertEqual('9',self.ui.nodes(desc='Repetições · legacy-0-0 · 1')[-1].get('text'))

    def test_04_check_hides_show_and_undo(self):
        self.ui.set_series();self.ui.check_series()
        self.assertFalse(self.ui.has(desc='Carga · legacy-0-0 · 1'))
        self.assertTrue(self.ui.has(text='1 de 2 séries concluídas'))
        self.ui.tap(text='Mostrar séries concluídas');self.ui.check_series()
        self.assertTrue(self.ui.has(desc='Carga · legacy-0-0 · 1'))
        self.assertFalse(self.ui.has(text='1 de 2 séries concluídas'))

    def test_05_checked_state_survives_restart(self):
        self.ui.set_series();self.ui.check_series();self.ui.restart()
        self.ui.scroll_to(text='1 de 2 séries concluídas')
        self.assertFalse(self.ui.has(desc='Carga · legacy-0-0 · 1'))
        self.ui.tap(text='Mostrar séries concluídas')
        self.assertEqual('true',self.ui.nodes(desc='Série 1 concluída em Supino reto barra')[-1].get('checked'))

    def test_06_finish_empty_does_not_create_history(self):
        self.ui.tap(scroll=True,text='Concluir e salvar treino')
        self.assertFalse(self.ui.has(text='Salvar treino?'));self.ui.history()
        self.assertTrue(self.ui.has(text='Nenhum treino concluído ainda.'))

    def test_07_invalid_checked_values_cannot_be_saved(self):
        self.ui.check_series();self.ui.tap(scroll=True,text='Concluir e salvar treino')
        self.assertFalse(self.ui.has(text='Salvar treino?'));self.ui.history()
        self.assertTrue(self.ui.has(text='Nenhum treino concluído ainda.'))

    def test_08_cancel_finish_keeps_draft(self):
        self.ui.set_series();self.ui.check_series();self.ui.finish(save=False)
        self.ui.restart();self.ui.scroll_to(text='1 de 2 séries concluídas')
        self.assertTrue(self.ui.has(text='1 de 2 séries concluídas'))

    def test_09_completed_session_history_and_previous_values(self):
        self.save_session();self.ui.history()
        self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))
        self.ui.tap(scroll=True,text='Voltar ao treino');self.ui.scroll_to(text='Último: 40 kg × 8')
        self.assertTrue(self.ui.has(text='Último: 40 kg × 8'))
        self.assertFalse(self.ui.has(text='1 de 2 séries concluídas'))

    def test_10_only_checked_series_enter_history(self):
        self.ui.set_series();self.ui.set_series(index=2,kg='30',reps='7')
        self.ui.check_series();self.ui.finish();self.ui.history()
        self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))
        self.assertNotIn('30 kg × 7',self.ui.last_xml)

    def test_11_timer_start_stop_and_restart(self):
        self.ui.tap(text='60 s');self.assertTrue(any('Descanso  0:' in n.get('text','') for n in self.ui.dump().iter('node')))
        self.ui.tap(text='Parar');self.assertTrue(self.ui.has(text='Descanso'))
        self.ui.tap(text='90 s');self.assertTrue(any('Descanso  1:' in n.get('text','') for n in self.ui.dump().iter('node')))
        self.ui.tap(text='120 s');self.assertTrue(any('Descanso  1:' in n.get('text','') or 'Descanso  2:' in n.get('text','') for n in self.ui.dump().iter('node')))
        self.ui.tap(text='Parar')

    def test_12_import_changes_plan_preserves_old_history(self):
        self.save_session();self.plan_import()
        self.ui.scroll_to(text='Supino atualizado');self.assertTrue(self.ui.has(text='1 séries × 6–8 reps'))
        self.assertFalse(self.ui.has(desc='Carga · legacy-0-0 · 2'))
        self.ui.scroll_to(text='Último: 40 kg × 8');self.assertTrue(self.ui.has(text='Último: 40 kg × 8'))
        self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_13_cancel_plan_import_does_not_change_plan(self):
        self.ui.import_plan(FIXTURES/'updated.json');self.ui.wait(lambda:self.ui.has(text='Importar ficha?'))
        self.ui.tap(text='Cancelar');self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))

    def test_14_import_is_blocked_while_draft_exists(self):
        self.ui.set_series();self.ui.import_plan(FIXTURES/'updated.json')
        self.ui.wait(lambda:self.ui.has(text='Importar ficha?'));self.ui.tap(text='Importar')
        self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))
        self.ui.scroll_to(desc='Carga · legacy-0-0 · 1');self.assertEqual('40',self.ui.nodes(desc='Carga · legacy-0-0 · 1')[-1].get('text'))

    def test_15_invalid_and_malformed_plan_rejected(self):
        for name in ['invalid.json','malformed.json']:
            self.ui.import_plan(FIXTURES/name);self.ui.wait(lambda:self.ui.has(text='Meu Treino'))
            self.assertFalse(self.ui.has(text='Importar ficha?'))
            self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))

    def test_16_export_restore_roundtrip_with_history_and_draft(self):
        self.save_session();self.ui.set_series(kg='47.5',reps='6')
        backup=self.ui.export_backup();self.assertEqual(2,backup['version']);self.assertEqual(1,len(backup['history']))
        self.assertEqual('47.5',backup['draft0']['0_0kg'])
        self.ui.reset();self.ui.restore_backup(self.json_file('roundtrip.json',backup))
        self.ui.wait(lambda:self.ui.has(text='Restaurar backup?'));self.ui.tap(text='Restaurar')
        self.ui.restart();self.ui.scroll_to(desc='Carga · legacy-0-0 · 1')
        self.assertEqual('47.5',self.ui.nodes(desc='Carga · legacy-0-0 · 1')[-1].get('text'))
        self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_17_cancel_backup_restore_keeps_history(self):
        self.save_session();empty={'version':1,'phase':0,'history':[],**{f'draft{i}':{} for i in range(5)}}
        self.ui.restore_backup(self.json_file('empty-backup.json',empty));self.ui.wait(lambda:self.ui.has(text='Restaurar backup?'));self.ui.tap(text='Cancelar')
        self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_18_legacy_backup_restores_original_plan(self):
        self.plan_import();legacy={'version':1,'phase':2,'history':[{'day':0,'date':'01/10/2026 10:00','sets':{'0_0done':True,'0_0kg':'35','0_0reps':'10'}}],**{f'draft{i}':{} for i in range(5)}}
        self.ui.restore_backup(self.json_file('legacy-backup.json',legacy));self.ui.wait(lambda:self.ui.has(text='Restaurar backup?'));self.ui.tap(text='Restaurar')
        self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))
        self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n35 kg × 10'))

    def test_19_invalid_backup_cannot_replace_history(self):
        self.save_session();bad={'version':2,'phase':9,'history':[]}
        self.ui.restore_backup(self.json_file('bad-backup.json',bad));self.ui.wait(lambda:self.ui.has(text='Meu Treino'))
        self.assertFalse(self.ui.has(text='Restaurar backup?'));self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_20_https_update_applies_new_revision(self):
        self.ui.configure_url(self.url+'/updated.json')
        self.ui.wait(lambda:self.ui.has(text='Ficha E2E revisada'),30)
        self.assertIn('/updated.json',FixtureHandler.requests)
        self.ui.restart();self.assertTrue(self.ui.has(text='Ficha E2E revisada'))

    def test_21_auto_update_on_launch_after_pending_draft_saved(self):
        self.ui.set_series();self.ui.configure_url(self.url+'/updated.json')
        self.ui.wait(lambda:bool(FixtureHandler.requests),30);self.ui.restart()
        self.assertTrue(self.ui.has(text='William · Segunda a sexta'))
        self.ui.check_series();self.ui.finish();self.ui.restart()
        self.ui.wait(lambda:self.ui.has(text='Ficha E2E revisada'),30)
        self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_22_older_revision_does_not_downgrade(self):
        self.plan_import();self.ui.configure_url(self.url+'/original.json')
        self.ui.wait(lambda:bool(FixtureHandler.requests),30);self.ui.restart()
        self.assertTrue(self.ui.has(text='Ficha E2E revisada'))

    def test_23_network_errors_keep_offline_plan(self):
        for endpoint in ['/fail','/invalid.json','/malformed.json','/redirect']:
            FixtureHandler.requests=[];self.ui.configure_url(self.url+endpoint)
            self.ui.wait(lambda:bool(FixtureHandler.requests),30)
            self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))
        self.ui.set_series();self.ui.check_series();self.ui.finish();self.ui.history()
        self.assertTrue(self.ui.has(text='Supino reto barra\n40 kg × 8'))

    def test_24_invalid_url_and_disable_sync(self):
        self.ui.configure_url('http://localhost/updated.json')
        self.assertFalse(FixtureHandler.requests)
        self.ui.configure_url(self.url+'/original.json');self.ui.wait(lambda:bool(FixtureHandler.requests),30)
        self.ui.tap(scroll=True,text='Atualização online');self.ui.tap(text='Desativar')
        FixtureHandler.requests=[];self.ui.restart();time.sleep(1)
        self.assertFalse(FixtureHandler.requests)

    def test_25_selected_day_and_phase_survive_restart(self):
        self.ui.choose_day('Sexta');self.ui.phase();self.ui.restart()
        self.assertTrue(self.ui.has(text='Rosca Scott'))
        self.ui.scroll_to(desc='Carga · legacy-4-0 · 3');self.assertTrue(self.ui.has(desc='Carga · legacy-4-0 · 3'))

    def test_26_timer_reaches_completion(self):
        self.ui.tap(text='60 s')
        self.ui.wait(lambda:self.ui.has(text='Descanso concluído'),85)

    def test_27_rotation_preserves_draft_and_timer(self):
        self.ui.set_series(kg='45',reps='7');self.ui.top();self.ui.tap(text='120 s')
        self.ui.shell('settings put system accelerometer_rotation 0')
        self.ui.shell('settings put system user_rotation 1')
        self.ui.wait(lambda:self.ui.has(text='Meu Treino'),30)
        self.ui.shell('settings put system user_rotation 0')
        self.ui.wait(lambda:self.ui.has(text='Meu Treino'),30)
        self.ui.scroll_to(desc='Carga · legacy-0-0 · 1')
        self.assertEqual('45',self.ui.nodes(desc='Carga · legacy-0-0 · 1')[-1].get('text'))
        self.ui.top();self.assertTrue(any(n.get('text','').startswith('Descanso  ') for n in self.ui.dump().iter('node')))
        self.ui.tap(text='Parar')

    def test_28_cancel_file_picker_leaves_app_usable(self):
        for button in ['Importar ficha de treino','Exportar backup','Restaurar backup']:
            self.ui.tap(scroll=True,text=button)
            self.ui.wait(lambda:self.ui.has(package='com.android.documentsui'),30)
            self.ui.shell('input keyevent 4');self.ui.wait(lambda:self.ui.has(text='Meu Treino'),30)
        self.ui.restart();self.assertTrue(self.ui.has(text='William · Segunda a sexta'))

    def test_29_zero_weight_valid_zero_repetitions_invalid(self):
        self.ui.set_series(kg='0',reps='0');self.ui.check_series()
        self.ui.tap(scroll=True,text='Concluir e salvar treino');self.assertFalse(self.ui.has(text='Salvar treino?'))
        self.ui.top();self.ui.tap(scroll=True,text='Mostrar séries concluídas')
        self.ui.fill('8',desc='Repetições · legacy-0-0 · 1')
        self.ui.finish();self.ui.history();self.assertTrue(self.ui.has(text='Supino reto barra\n0 kg × 8'))

    def test_30_version2_backup_restores_imported_plan(self):
        self.plan_import();backup=self.ui.export_backup('e2e-plan-backup.json')
        self.assertEqual(2,backup['plan']['revision'])
        self.ui.reset();self.ui.restore_backup(self.json_file('revised-backup.json',backup))
        self.ui.wait(lambda:self.ui.has(text='Restaurar backup?'));self.ui.tap(text='Restaurar')
        self.ui.restart();self.assertTrue(self.ui.has(text='Ficha E2E revisada'))
        self.ui.scroll_to(text='Supino atualizado');self.assertTrue(self.ui.has(text='1 séries × 6–8 reps'))

if __name__=='__main__': unittest.main(verbosity=2)
