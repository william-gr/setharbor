'use strict';
try {
  const handoff = workoutHandoff(location.hash);
  document.getElementById('status').textContent = handoff.title;
  document.getElementById('open').href = handoff.intent;
  document.getElementById('direct').href = handoff.direct;
  document.getElementById('open').hidden = false;
  document.getElementById('hint').hidden = false;
} catch (error) {
  document.getElementById('status').textContent = 'Link inválido. Peça ao ChatGPT para gerar novamente a ficha.';
}
