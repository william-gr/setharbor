const test = require('node:test');
const assert = require('node:assert/strict');
const handoff = require('../web/open/link.js');
const fs = require('node:fs');
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
