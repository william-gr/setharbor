# Verificação E2E

## Suíte original — aprovada

Em 2026-10-10, o commit `41b4268` passou os 30 cenários completos em **ambas** as APIs de CI, sem erros ou skips:

| Ambiente | Resultado | Duração do job |
| --- | --- | --- |
| Android API 29, x86_64, Google APIs | 30/30 | 30m47s |
| Android API 35, x86_64, Google APIs | 30/30 | 50m29s |

[Execução 38045908448](https://github.com/william-gr/setharbor/actions/runs/38045908448). Os dois `results.json` dos artefatos foram baixados e verificados: `complete: true`, `tests_run: 30`, `success: true` e todas as entradas `passed`. Build/lint passou em ambos os jobs.

A suíte original também passou localmente em 2026-10-08, API 35 ARM64 com aceleração HVF, 30/30 em 2164,456 segundos. O dispositivo foi um emulador descartável; nenhum telefone pessoal foi usado. JDK 17/SDK 35 e Python padrão.

### Diagnósticos que levaram à aprovação

- Android exige constantes de orientação explícitas para o lint. O cronômetro agora só altera o texto quando o segundo visível muda, evitando eventos de acessibilidade redundantes.
- O driver verifica foco e valor de campos, aceita a capitalização de botões nativos e filtra nós com bounds sem área visível.
- Cada dump remove o arquivo anterior e exige confirmação de geração, evitando XML antigo após falha de UI Automator.
- DocumentsUI AOSP (API 29) usa navegação normal; sua busca perde caracteres e pode causar crash de SearchFragment. Google DocumentsUI usa busca real por nome e resource-id do título, evitando linhas recicladas que ocultavam arquivos no XML.
- Limpeza de preparação permite uma única repetição somente após erros reconhecidos de transporte ADB. Stdout/stderr são preservados; assertions não são repetidas.

Execuções anteriores com diagnóstico: [37833596780](https://github.com/william-gr/setharbor/actions/runs/37833596780), [37928823706](https://github.com/william-gr/setharbor/actions/runs/37928823706), [37961278915](https://github.com/william-gr/setharbor/actions/runs/37961278915), [37974858007](https://github.com/william-gr/setharbor/actions/runs/37974858007). Elas foram substituídas pela execução aprovada acima.

## Catálogo e cartões compactos

Requisitos e dados recuperados da continuação em cloud. Catálogo com 90 exercícios, 12 grupos e 35 músculos; troca aleatória por família só na sessão, bloqueio com dados, identidade do movimento separada da posição, snapshots reais e backups v3 aceitando v1/v2.

Informações ficam ocultas por padrão; o ícone de detalhes expande o conteúdo e o ícone pequeno de troca fica no canto. Ambos têm alvos de toque de 48 dp e descrições acessíveis. Layout inspecionado no emulador.

- 13 testes JVM passaram; build/lint dos APKs debug e E2E passou sem erros.
- Quatro cenários novos 31–34 passaram em API 35 em 621,166 segundos antes do ajuste final de exportação v3.
- Cenários 31 e 35 passaram no APK final com v3 e ícones em 144,587 segundos.
- A execução intermediária de 34 cenários foi interrompida deliberadamente após oito passagens, sem falhas, para incorporar a preferência de interface.
- A regressão completa local em API 35 passou **35/35**, sem skips, em **3076,091 segundos**, no commit `bede881`. O relatório foi verificado: `complete: true`, `tests_run: 35`, `success: true`, todas as entradas `passed`.
- Na matriz de [CI 38048862218](https://github.com/william-gr/setharbor/actions/runs/38048862218), API 29 passou **35/35**, sem skips, em um job de **36m43s**; seu artefato foi baixado e verificado. API 35 terminou com **34/35**: cenário 16 interrompido pelo processo UI Automator com exit 137 após escrever XML; nenhuma assertion de produto falhou. Todos os cinco cenários novos passaram. O driver agora descarta o dump e tenta novamente somente esse erro, até três tentativas, preservando a falha se persistir. Três testes de recuperação passaram (XML fresco, limite de tentativas e propagação de outros erros). Nova matriz pendente.
- Depois da regressão, apenas dois textos de orientação foram ajustados: a unidade de carga fica nos detalhes e a progressão de exercícios assistidos reduz a assistência. Build/lint e os 13 testes JVM passaram novamente; os cenários 01 e 35 passaram novamente em 115,010 segundos.

[PR #1](https://github.com/william-gr/setharbor/pull/1) permanece draft durante a verificação. Artefatos locais em `e2e/artifacts/catalog-targeted`, `catalog-icons-targeted` e `catalog-icons-full`, ignorados pelo Git. Fixtures/CA só entram no APK E2E. O app permanece gratuito, offline e MIT.
