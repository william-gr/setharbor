"""Generate a static, readable guide from the app's canonical offline catalog."""
import argparse, html, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'app/src/main/assets/exercise-catalog.json'
TARGET=ROOT/'web/chatgpt'

def render():
    catalog=json.loads(CATALOG.read_text())
    link_source=(ROOT/'app/src/main/java/com/william/treino/WorkoutLink.java').read_text()
    base=re.search(r'WEB_BASE="([^"]+)"',link_source)[1]
    limit=int(re.search(r'MAX_LENGTH=(\d+)',link_source)[1])
    labels={key:{item['id']:item['name']['pt'] for item in catalog[key]} for key in ['groups','equipment','muscles']}
    rows=[]
    for exercise in catalog['exercises']:
        cells=[exercise['id'],exercise['name']['pt'],exercise['name']['en'],labels['groups'][exercise['group']],', '.join(labels['equipment'][v] for v in exercise['equipment']),', '.join(labels['muscles'][v] for v in exercise['primaryMuscles'])]
        rows.append('<tr>'+''.join('<td>'+html.escape(value)+'</td>' for value in cells)+'</tr>')
    example=json.loads((ROOT/'e2e/fixtures/link-three-day.json').read_text())
    example['days']=example['days'][:1]
    encoding="""import base64, json
payload = base64.urlsafe_b64encode(
    json.dumps(plan, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
).decode().rstrip('=')
url = '"""+base+"""#v1.' + payload
assert len(url) <= """+str(limit)
    return '''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'">
<title>SetHarbor · instruções e catálogo para ChatGPT</title><link rel="stylesheet" href="../open/style.css"><link rel="stylesheet" href="guide.css">
<main><h1>Planejar com ChatGPT</h1>
<p>Compartilhe um pedido curto com o ChatGPT. As instruções e o catálogo ficam nesta página; sua ficha, histórico e cargas não são enviados por este botão.</p>
<button id="share" type="button">Planejar com ChatGPT</button><p id="share-status" role="status"></p>
<p>Depois de conversar, toque no link devolvido pelo ChatGPT para revisar e aplicar a ficha no SetHarbor já instalado.</p>
<h2>Instruções para o ChatGPT</h2>
<p>Pergunte objetivos, frequência e equipamentos antes de criar. Organize uma sequência cíclica A/B/C; faltar um dia não muda o próximo treino. Use os catalogIds exatos da tabela abaixo e adapte volume/repetições ao pedido. Ao revisar, incremente revision e preserve os IDs dos treinos mantidos para conservar o próximo da sequência. Use IDs novos para um programa novo. Ao revisar uma ficha enviada, preserve IDs de posições somente se o movimento permanecer igual. Não invente catalogIds. Se não puder consultar esta página ou executar a codificação, explique a limitação em vez de inventar um link.</p>
<p>Entregue um link clicável com o texto <strong>Abrir no SetHarbor</strong>, não uma solicitação para copiar JSON ou importar arquivo. Mostre também um resumo do treino para revisão. A ficha fica no fragmento do próprio link; não hospede a ficha do usuário nem envie histórico/cargas para esta página.</p>
<h2>Contrato da ficha</h2>
<ul><li>format: meu-treino-plan; schemaVersion: 1; revision: inteiro positivo, maior que a revisão atual quando fornecida.</li>
<li>title: texto não vazio até 120 caracteres; days: 1–7 treinos em ordem cíclica.</li>
<li>Treino (campo days, preservado por compatibilidade): id único na ficha (até 80), name (até 80), focus opcional não vazio (até 200), exercises: 1–20 exercícios.</li>
<li>Exercício: id único na ficha inteira (até 80), catalogId da tabela, name (até 120), sets inteiro 1–10, reps texto não vazio (até 40).</li>
<li>id identifica a posição; catalogId identifica o movimento. O mesmo movimento em dias diferentes precisa de IDs de posição diferentes.</li></ul>
<pre>'''+html.escape(json.dumps(example,ensure_ascii=False,indent=2))+'''</pre>
<h2>Gerar o link de treino</h2>
<p>Execute este código com o objeto plan validado. Use JSON UTF-8 completo e Base64URL sem padding. A URL completa tem limite de '''+str(limit)+''' caracteres. Não use um encurtador ou link para baixar arquivo.</p>
<pre>'''+html.escape(encoding)+'''</pre>
<p>Retorne em Markdown: [Abrir no SetHarbor](URL_GERADA). O app valida e pede confirmação. Se abrir no navegador, a página oferece um botão para abrir o app. Treinos em andamento bloqueiam a troca; sessões anteriores são preservadas.</p>
<h2>Catálogo offline · '''+str(len(catalog['exercises']))+''' exercícios · revisão '''+str(catalog['revision'])+'''</h2>
<p>Dados idênticos ao catálogo do app. Consulte somente os movimentos relevantes ao equipamento/objetivo. <a href="catalog.json">Catálogo completo em JSON</a>.</p>
<div class="table-scroll"><table><thead><tr><th>catalogId</th><th>Nome</th><th>English name</th><th>Grupo</th><th>Equipamento</th><th>Músculos principais</th></tr></thead><tbody>
'''+ '\n'.join(rows)+'''
</tbody></table></div>
<p><a href="../">Teste de links e APK Trial</a> · <a href="https://github.com/william-gr/setharbor">Código aberto · MIT</a></p>
</main><script src="share.js"></script></html>
'''

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    document=render();target=TARGET/'index.html'
    if args.check:
        if not target.exists() or target.read_text()!=document: raise SystemExit('ChatGPT guide is stale; run python3 scripts/build_chatgpt_guide.py')
        print('Guide matches the canonical catalog and app link contract')
    else:
        TARGET.mkdir(parents=True,exist_ok=True);target.write_text(document)
        (TARGET/'catalog.json').write_bytes(CATALOG.read_bytes())
        print('Generated ChatGPT guide and canonical catalog JSON')
