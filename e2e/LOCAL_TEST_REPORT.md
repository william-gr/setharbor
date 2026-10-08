# Verificação local — 2026-10-08

## Verificado

- APK pessoal e APK E2E compilados com as ferramentas do SDK.
- Assinaturas verificadas.
- Certificado/configuração E2E ausentes no APK pessoal.
- Sintaxe de todos os scripts Python validada.
- 30 cenários E2E descobertos no código.
- YAML, gatilhos PR/main e matriz API 29/35 do workflow validados.
- Validador de fichas: oito verificações passaram em execução JVM anterior.

## Execução em emulador

Emulador Android API 29 iniciado sem KVM. Primeira tentativa de instalação excedeu 45 segundos; a tentativa seguinte, com prazo maior, instalou o APK e começou a suíte. Os cenários iniciais falharam na preparação da interface. Uma captura mostrou o diálogo Android “System UI isn't responding” sobre o aplicativo aberto, bloqueando a UI. A execução foi interrompida após confirmar esse impedimento da infraestrutura.

**A suíte completa não passou nem foi concluída localmente.** Não interpretar compilação ou descoberta de testes como aprovação E2E. O CI foi preparado para uma execução completa com KVM, mas só se pode afirmar aprovação após consultar seus resultados reais.

Uma screenshot do bloqueio e o log dessa execução ficam disponíveis como diagnóstico separado da entrega. Os testes normais não ignoram ANRs do aplicativo ou do sistema.
