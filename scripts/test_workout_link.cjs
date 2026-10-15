const test = require('node:test');
const assert = require('node:assert/strict');
const handoff = require('../web/open/link.js');
const fs = require('node:fs');
const vm = require('node:vm');
const newWorkoutRequest = require('../web/chatgpt/share.js');
const fragment = plan => '#v1.' + Buffer.from(JSON.stringify(plan)).toString('base64url');
test('Unicode workout survives both handoff formats, without HTML interpolation', () => {
  const plan = {format:'meu-treino-plan',schemaVersion:1,title:'Força 💪 <script>',days:[{name:'Terça'}]};
  const hash = fragment(plan), result = handoff(hash);
  assert.equal(result.title,plan.title);
  assert.equal(result.direct,'setharbor://workout'+hash);
  assert.equal(result.intent,'intent://workout'+hash+'#Intent;scheme=setharbor;end');
});
test('rejects missing, malformed, excessive, non-UTF8 and incompatible payloads', () => {
  for (const value of [undefined,'','#v2.YQ','#v1.','<script>','#v1.A','#v1._w','#v1.'+'A'.repeat(64000),fragment({}),fragment({format:'other',schemaVersion:1,title:'X',days:[{}]}),fragment({format:'meu-treino-plan',schemaVersion:1,title:3,days:[{}]}),fragment({format:'meu-treino-plan',schemaVersion:1,title:'X',days:[]})]) {
    assert.throws(() => handoff(value));
  }
});
test('published three-day trial link matches the Android E2E fixture', () => {
  const html = fs.readFileSync('web/index.html','utf8');
  const url = html.match(/href="(https:\/\/william-gr\.github\.io\/setharbor\/open\/#[^"]+)"/)[1];
  const hash = new URL(url).hash;
  const plan = JSON.parse(Buffer.from(hash.slice(4),'base64url').toString('utf8'));
  assert.deepEqual(plan, JSON.parse(fs.readFileSync('e2e/fixtures/link-three-day.json','utf8')));
  assert.equal(handoff(hash).title,plan.title);
  assert.equal(plan.days.length,3);
});
test('short web prompt points to readable canonical guide without embedding exercises', () => {
  const prompt=newWorkoutRequest();
  assert.ok(prompt.length<500);
  assert.ok(prompt.includes('https://william-gr.github.io/setharbor/chatgpt/'));
  assert.ok(prompt.includes('não invente'));
  assert.ok(!prompt.includes('barbell-bench-press'));
  const guide=fs.readFileSync('web/chatgpt/index.html','utf8');
  const catalog=JSON.parse(fs.readFileSync('app/src/main/assets/exercise-catalog.json','utf8'));
  assert.equal((guide.match(/<tr><td>/g)||[]).length,catalog.exercises.length);
  for(const exercise of catalog.exercises) assert.ok(guide.includes('<td>'+exercise.id+'</td>'));
  assert.ok(guide.includes('urlsafe_b64encode'));assert.ok(guide.includes('ensure_ascii=False'));
});
test('web button shares only short text and handles cancellation or unavailable sharing', async () => {
  async function click(navigator) {
    let callback;const status={textContent:''};
    const document={getElementById:id => id==='share'?{addEventListener:(event,fn)=>callback=fn}:status};
    vm.runInNewContext(fs.readFileSync('web/chatgpt/share.js','utf8'),{document,navigator});
    await callback();return status.textContent;
  }
  let sent;
  assert.ok((await click({share:async value=>sent=value})).includes('Pedido compartilhado'));
  assert.deepEqual(Object.keys(sent),['text']);assert.equal(sent.text,newWorkoutRequest());
  assert.ok((await click({})).includes('navegador do celular'));
  assert.equal(await click({share:async()=>{throw {name:'AbortError'};}}),'Compartilhamento cancelado.');
  assert.ok((await click({share:async()=>{throw Error('unavailable');}})).includes('Não foi possível'));
});
test('handoff button uses custom scheme on iOS and intent on Android', () => {
  for (const userAgent of ['iPhone OS 27', 'Android 15', 'Macintosh']) {
    const elements = Object.fromEntries(['status', 'open', 'direct', 'hint'].map(id => [id, {hidden:true}]));
    const hash = fragment({format:'meu-treino-plan',schemaVersion:1,title:'Treino',days:[{}]});
    vm.runInNewContext(fs.readFileSync('web/open/page.js','utf8'), {
      location:{hash}, navigator:{userAgent}, workoutHandoff:handoff,
      document:{getElementById:id => elements[id]},
    });
    assert.equal(elements.open.href, /Android/.test(userAgent) ? handoff(hash).intent : handoff(hash).direct);
    assert.equal(elements.direct.href, handoff(hash).direct);
    assert.equal(elements.open.hidden,false);
  }
});
