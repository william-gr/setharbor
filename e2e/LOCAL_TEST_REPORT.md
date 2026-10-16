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

## Catálogo e cartões compactos — aprovado

Requisitos e dados recuperados da continuação em cloud. Catálogo com 90 exercícios, 12 grupos e 35 músculos; troca aleatória por família só na sessão, bloqueio com dados, identidade do movimento separada da posição, snapshots reais e backups v3 aceitando v1/v2.

Informações ficam ocultas por padrão; o ícone de detalhes expande o conteúdo e o ícone pequeno de troca fica no canto. Ambos têm alvos de toque de 48 dp e descrições acessíveis. Layout inspecionado no emulador.

- 13 testes JVM passaram; build/lint dos APKs debug e E2E passou sem erros.
- Quatro cenários novos 31–34 passaram em API 35 em 621,166 segundos antes do ajuste final de exportação v3.
- Cenários 31 e 35 passaram no APK final com v3 e ícones em 144,587 segundos.
- A execução intermediária de 34 cenários foi interrompida deliberadamente após oito passagens, sem falhas, para incorporar a preferência de interface.
- A regressão completa local em API 35 passou **35/35**, sem skips, em **3076,091 segundos**, no commit `bede881`. O relatório foi verificado: `complete: true`, `tests_run: 35`, `success: true`, todas as entradas `passed`.
- Na matriz de [CI 38048862218](https://github.com/william-gr/setharbor/actions/runs/38048862218), API 29 passou **35/35**, sem skips, em um job de **36m43s**; seu artefato foi baixado e verificado. API 35 terminou com **34/35**: cenário 16 interrompido pelo processo UI Automator com exit 137 após escrever XML; nenhuma assertion de produto falhou. Todos os cinco cenários novos passaram. O driver agora descarta o dump e tenta novamente somente esse erro, até três tentativas, preservando a falha se persistir. Três testes de recuperação passaram (XML fresco, limite de tentativas e propagação de outros erros). O cenário 16 passou localmente após a correção em 189,040 segundos. A nova [matriz 38054423441](https://github.com/william-gr/setharbor/actions/runs/38054423441), commit `571ac5d`, passou **35/35 em API 29 e 35**, sem skips. Ambos os artefatos foram baixados e conferidos (`complete: true`, `tests_run: 35`, `success: true`, todas as entradas `passed`). Jobs: API 29 **38m58s**, API 35 **59m56s**. Build/lint, 13 testes JVM e três checks do driver passaram em ambas as APIs.
- Depois da regressão, apenas dois textos de orientação foram ajustados: a unidade de carga fica nos detalhes e a progressão de exercícios assistidos reduz a assistência. Build/lint e os 13 testes JVM passaram novamente; os cenários 01 e 35 passaram novamente em 115,010 segundos.

O usuário autorizou merge direto na `main` após aprovação dos testes. As alterações posteriores ao commit testado são apenas documentação; a documentação final usa `[skip ci]` para evitar uma matriz duplicada. Artefatos locais em `e2e/artifacts/catalog-targeted`, `catalog-icons-targeted` e `catalog-icons-full`, ignorados pelo Git. Fixtures/CA só entram no APK E2E. O app permanece gratuito, offline e MIT.


## Gate de cobertura — 2026-10-10

13 regressões JVM adicionais, 26 no total: catálogo com versão/IDs/referências/aliases inválidos, tradução de unidades de carga, restrições de similaridade, identidade de exercícios futuros/personalizados, tipos inválidos em overrides, preservação de outras trocas/dias no snapshot e limites/duplicações/campos obrigatórios da ficha. Os 35 E2E já aprovados cobrem os fluxos de UI, incluindo ícones e informações ocultas; não foram adicionados cenários redundantes.

JaCoCo 0.8.14: `coreCoverageVerification` exige 90% de linhas e 80% de branches **por classe**, executando testes e relatório. `check` e o build de CI dependem do gate antes de abrir o emulador. Escopo inclui automaticamente todas as classes Java da aplicação, exceto Activity/classes internas e código Android gerado; não representa cobertura de toda a interface. HTML/XML em `app/build/reports/jacoco/coreCoverageReport/`. Prerequisito separado impede que dados ausentes sejam tratados como um relatório ignorado com sucesso. Helpers estáticos têm construtores privados vazios, impedindo instanciação sem finalidade; JaCoCo filtra esses construtores.

| Classe | Linhas | Branches |
| --- | --- | --- |
| ExerciseCatalog | 100% | 100% |
| ExerciseSession | 100% | 91,38% |
| WorkoutPlan | 100% | 100% |

26/26 JVM, 3/3 checks do driver, gate, builds debug/E2E e lint passaram localmente. O teste negativo executou somente WorkoutPlanTest: o gate falhou por cobertura 0% nas outras duas classes. Outro teste removeu temporariamente os dados de cobertura e excluiu a execução JVM: o prerequisito falhou explicitamente; o arquivo foi restaurado e a suíte completa passou novamente. [Documentação do plugin Gradle](https://docs.gradle.org/8.9/userguide/jacoco_plugin.html).

## Protótipo de links ChatGPT — 2026-10-11

34/34 testes JVM, gate de cobertura, builds debug/E2E/preview e lint debug/preview passaram. WorkoutLink e WorkoutChatPrompt têm 100% de linhas e branches; limites continuam 90%/80% por classe. Três checks do fallback web e três checks do driver passaram. APK preview confirma pacote com.william.treino.preview / SetHarbor Trial, sem certificados/recursos de confiança E2E.

- Novos cenários 36–39 passaram em API 35 em 209,351 segundos: links cold/warm, Unicode, cancelar/aplicar/persistir/histórico, três dias, malformação, proteção de rascunhos e rotação/substituição de preview.
- Regressões 12/14/20/27 e cenário 37 com a fixture pública passaram na execução de 381,548 segundos; cenário 40 falhou nessa execução somente porque o comando de setup pm set-app-links-user-selection estava sem --package. O erro foi consultado no artefato e o comando corrigido.
- No APK final, cenários 39/40/41 passaram em 77,326 segundos: rotação com limpeza do diálogo, intents do browser e HTTPS resolvidos pelo sistema, share chooser e configurações Android reais. Nenhuma assertion foi removida. A seleção do domínio é aplicada e restaurada apenas no pacote E2E.

Seis cenários novos (36–41) e quatro regressões apropriadas passaram localmente, sem skips. Não representa uma execução completa dos 41 cenários nem comprova comportamento do ChatGPT/Chrome no telefone. A matriz completa API29/35 executa após push. O teste real permanece pendente em TODO.md e docs/CHATGPT_LINKS.md: receber prompt, gerar Base64URL correto e preservar/abrir fragmento.

## Prompt curto e guia público — 2026-10-11

Criar envia apenas pedido curto, revisão atual e URL fixa do guia; revisar inclui somente o contrato sanitizado da ficha. O catálogo de 90 exercícios e instruções de codificação estão no HTML público gerado do asset/constantes reais. O pedido original da ficha padrão tinha cerca de 13.934 caracteres; o teste de criação exige menos de 650 caracteres e comprova ausência da ficha/catálogo/metadados.

35 testes JVM, gate por classe (WorkoutChatPrompt 100% linhas/branches), builds debug/E2E/preview e lint debug/preview passaram. Cinco checks web verificam links existentes, catálogo público, tamanho/privacidade do pedido, Web Share, cancelamento e indisponibilidade. Três checks do driver passaram. O cenário 41 atualizado abriu os dois share choosers reais (criar e revisar) e as configurações Android em API35, sem skips, em 39,796 segundos. Não foi repetida localmente a suíte completa dos 41 cenários para esta alteração do prompt.

A página pública oferece compartilhamento de um pedido curto sem dados pessoais, usando o Trial já instalado e sem exigir atualização/reinstalação. A consulta do guia pelo ChatGPT do usuário permanece pendente; o relato anterior indicou que o handoff original pareceu funcionar.

## Valores opcionais e pesquisa de execução — 2026-10-14

Peso e repetições podem ficar vazios independentemente em séries marcadas como feitas. Valores preenchidos continuam validados; salvar exige ao menos uma série feita. Strings vazias permanecem no backup v3, sem virar zero. Histórico apresenta conclusão e dados parciais; Último ignora sessões daquele exercício sem medições. Links Google usam o nome real do exercício, inclusive trocado/personalizado, com UTF-8 e query escaping.

39 testes JVM, gate de cobertura, APKs debug/E2E/preview e lint debug/preview passaram. WorkoutSet tem 100% linhas/branches; ExerciseSearch tem 100% linhas, sem decisões de branch. Build local usou OpenJDK21 instalado (o JDK17 temporário foi removido); CI continua usando17. O AVD descartável API35 também foi recriado após remoção dos arquivos temporários. Cinco checks web, três checks do driver e verificação do guia canônico passaram.

Na execução local API35 de 582,546 segundos, cenários07/09/29/42/43 passaram: valores inválidos não vazios, histórico medido legado, zero kg, campos vazios/parciais, persistência e exportação/restauração real de backup. Cenário44 falhou somente porque o teste procurava a URL completa no dump de Activity após o Chrome entrar na tela de primeira execução; Android oculta path/query nos dumps/logs. O teste agora verifica VIEW/Google/Chrome reais para nomes planejados, trocados e personalizados, sem aceitar termos do Chrome; JVM verifica queries exatas, Unicode e caracteres reservados. Cenários40/44 passaram na execução final em80,892 segundos. Não foi repetida localmente a suíte completa de44 cenários.

A matriz anterior38180983165 terminou: API35 sucesso; API29 teve40/41 passagens (resultado baixado), com falha apenas no cenário40. A screenshot/XML mostra o seletor Open william-gr.github.io links with (Chrome/SetHarbor/Just once). O teste agora seleciona SetHarbor/Just once no Android10; API31+ conserva seleção de domínio por comando. A validação dessa correção em API29 fica para a nova matriz CI.


## Sequência cíclica A–G — 2026-10-14

Implementado cursor por ID estável, separado da seleção de tela/calendário. Confirmar o treino esperado avança; o último retorna a A. Sessões fora da ordem são extras e mantêm cursor. Definir como próximo reposiciona sem criar histórico/apagar rascunhos. Abertura retoma o rascunho da última seleção ou sugere o próximo. Histórico legado conserva nomes; novos registros guardam ID/rótulo/extra/próximo. Backup v4 guarda cursor e seleção e restaura v1–v3. Revisões maiores com IDs de treino compartilhados preservam cursor sobrevivente em imports/links; HTTPS preserva ID sobrevivente; ficha nova/ID removido reinicia A.

Rodada completa local API35: **49/49**, sem skips, em **4904,040s**, artefatos `e2e/artifacts/cyclic-full`. Inclui regressões01–44 e novos45–49: avanço/cancelamento/wrap/reinício, extras, outros rascunhos, reposicionamento, v3/v4, revisão HTTPS, ficha nova e links com reordenação/remoção. Uma execução inicial foi interrompida após01 para ajustar continuidade de revisões; não foi contada como suíte aprovada.

Após refinamentos da migração (sessão cujo ID ainda existe mesmo com treinos adicionados/removidos), representação interna do cursor em JSON e setup/diagnóstico de abertura, o **APK final passou6/6** em **949,896s**, sem skips:01/06/07/47/50/51, artefatos `e2e/artifacts/cyclic-final`. Cenário47 também restaura um backupv3 cujo snapshot tem cinco treinos e ficha ativa tem dois, mantendo sucessor correto por ID. Cenário50 injeta falha real de escrita via chmod500 em shared_prefs **somente do pacote E2E**, compara histórico/rascunho/cursor/seleção, restaura permissões em finally, reinicia e salva com sucesso. Verifica rollback em memória e dados em disco. Cenário51 verifica IDs opacos com Unicode, aspas, NUL/CR/LF/SOH: reinício, avanço, reposicionamento, wrap, histórico e backup/restauração reais, preservando outro rascunho. O cursor interno é um array JSON com um único ID; v4 exporta o ID lógico como string. Esses resultados cobrem **51 cenários distintos em duas rodadas**, não uma execução única de51 no APK final.

**44/44 JVM**, gate90% linhas/80% branches por classe, APKs debug/E2E/preview e lint debug/preview passaram no build final. WorkoutSequence tem100% de linhas/branches; demais classes mantêm limites, sem novas exclusões. Cinco checks web, três checks do driver, py_compile e guia canônico passaram. OpenJDK21 local/SDK35; CI continua JDK17. App pessoal/celular não foram usados; somente AVD descartável/pacote E2E. Nenhum termo do Chrome foi aceito.

A matriz da versão anterior47758a5, execução38555356927, concluiu: **API35 44/44**, **API29 43/44**. Artefato API29 baixado: o cenário01 falhou em setUp ao aguardar a primeira abertura, com launcher em screenshot/XML; os outros43 passaram, incluindo40/44. Os logs disponíveis não comprovam a causa exata do timeout. O novo setup espera o launcher renderizado/desbloqueado antes da primeira abertura e registra a resposta de am start em last-launch.txt. Não faz retry de app que falhou; reset deixa o app selecionar A naturalmente. O limite agregado da CI foi elevado para120 minutos para51 cenários reais; timeouts/assertions individuais não foram relaxados. A nova matriz API29/35 será disparada ao publicar; ainda não foi declarada aprovada.


## Flutter / Riverpod — CI aprovada em 2026-10-16

A [execução38918416649](https://github.com/william-gr/setharbor/actions/runs/38918416649),
commit `f755776`, passou todos os jobs: 26 testes Flutter, análise/formatação,
gate90%linhas/80%branches por arquivo de lógica, três integrações Android35,
migração Java→Flutter/rollback real/documentos/links/share/HTTPS/lint, três
integrações Dart iOS em XCTest hospedado e dois testes nativos iOS. Artefatos
baixados e conferidos, sem falhas/skips. O backup iOS é exportado/restaurado pelo
Files e seu conteúdo único é comparado depois de substituir a ficha. A restauração
preserva o destino lembrado pelo Files. Android29 está adiado por preferência do
usuário; iPhone físico/assinatura e fluxo ChatGPT no iPhone seguem pendentes.
Detalhes e proveniência do Trial em [FLUTTER_MIGRATION.md](../docs/FLUTTER_MIGRATION.md).
