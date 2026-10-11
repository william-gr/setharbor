'use strict';
function newWorkoutRequest() {
  return 'Quero criar uma ficha nova no SetHarbor. Leia as instruções e o catálogo em https://william-gr.github.io/setharbor/chatgpt/ Pergunte meus objetivos, dias disponíveis e equipamentos antes de criar. Entregue um link clicável Abrir no SetHarbor, sem copiar JSON nem importar arquivo. Se não conseguir consultar a página ou gerar o link corretamente, avise; não invente IDs ou codificação.';
}
if (typeof module !== 'undefined') module.exports = newWorkoutRequest;
if (typeof document !== 'undefined') {
  document.getElementById('share').addEventListener('click', async () => {
    const status=document.getElementById('share-status');
    if (!navigator.share) {
      status.textContent='Abra esta página no navegador do Android para compartilhar com o ChatGPT.';
      return;
    }
    try {
      await navigator.share({text:newWorkoutRequest()});
      status.textContent='Pedido compartilhado. Continue a conversa no ChatGPT.';
    } catch (error) {
      status.textContent=error.name==='AbortError'?'Compartilhamento cancelado.':'Não foi possível compartilhar. Tente abrir esta página no navegador do Android.';
    }
  });
}
