'use strict';
// Shared by the landing page and its Node tests; no network or storage access.
function workoutHandoff(fragment) {
  if (typeof fragment !== 'string' || fragment.length + 44 > 64000 || !/^#v1\.[A-Za-z0-9_-]+$/.test(fragment)) {
    throw new Error('Link incompleto ou inválido. Peça ao ChatGPT para gerar novamente.');
  }
  const encoded = fragment.slice(4);
  const bytes = Uint8Array.from(atob(encoded.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
  const plan = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes));
  if (plan.format !== 'meu-treino-plan' || plan.schemaVersion !== 1 || typeof plan.title !== 'string' || !Array.isArray(plan.days) || !plan.days.length) {
    throw new Error('Este link não contém uma ficha SetHarbor.');
  }
  return {
    title: plan.title,
    direct: 'setharbor://workout' + fragment,
    intent: 'intent://workout' + fragment + '#Intent;scheme=setharbor;end'
  };
}
if (typeof module !== 'undefined') module.exports = workoutHandoff;
