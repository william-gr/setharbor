"""Real native HTTPS boundary: trusted fixture TLS only in the disposable E2E app."""
import http.server
import json
import ssl
import threading
from android_smoke import ui,disk,ROOT,ARTIFACTS

class Handler(http.server.BaseHTTPRequestHandler):
    requests=[]
    plan={}
    def do_GET(self):
        type(self).requests.append(self.path)
        if self.path=='/redirect':self.send_response(302);self.send_header('Location','/plan');self.end_headers();return
        if self.path=='/fail':self.send_error(503);return
        body=(b'x'*(1024*1024+1)) if self.path=='/large' else json.dumps(type(self).plan,ensure_ascii=False).encode()
        self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers()
        try:self.wfile.write(body)
        except (BrokenPipeError,ConnectionResetError,ssl.SSLError):pass
    def log_message(self,*args):pass

def run():
    assert ui.shell('getprop ro.kernel.qemu')=='1','Emulator only'
    ui.launch()
    assert not any(value for key,value in disk().items() if key.startswith('draft')),'Finish disposable drafts first'
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(ROOT/'e2e/fixtures/tls-cert.pem',ROOT/'e2e/fixtures/tls-key.pem')
    server.socket=context.wrap_socket(server.socket,server_side=True)
    port=server.server_port;ui.adb('reverse',f'tcp:{port}',f'tcp:{port}')
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        Handler.plan=json.loads(json.dumps(disk()['plan']));Handler.plan['revision']=200;Handler.plan['title']='Flutter HTTPS verified'
        ui.configure_url(f'https://localhost:{port}/plan')
        ui.wait(lambda:disk()['plan']['revision']==200,30)
        assert len(disk()['history'])==3
        print('PASS native trusted HTTPS applies higher revision, preserves history',flush=True)
        before=disk()['plan'];Handler.plan['revision']=201
        for path in ['/redirect','/fail','/large']:
            Handler.requests=[];ui.configure_url(f'https://localhost:{port}{path}')
            ui.wait(lambda:ui.has(text='Não foi possível buscar a ficha. O treino offline continua disponível.'),30)
            assert disk()['plan']==before
            assert Handler.requests==[path],Handler.requests
            ui.artifacts(ARTIFACTS/('network-'+path[1:]))
        print('PASS native HTTPS rejects redirects, HTTP errors and >1MB responses',flush=True)
        # Explicit disable prevents the disposable fixture URL from lingering.
        ui.tap(scroll=True,text='Atualização online');ui.tap(text='Desativar')
        ui.wait(lambda:disk()['planUrl']=='')
        (ARTIFACTS/'network-results.json').write_text(json.dumps({'higherRevision':True,'redirectRejected':True,'httpErrorRejected':True,'sizeLimit':True},indent=2))
    finally:
        server.shutdown();server.server_close();ui.adb('reverse','--remove',f'tcp:{port}',check=False)
if __name__=='__main__':
    try:run()
    except BaseException:ui.artifacts(ARTIFACTS/'network-failure');raise
