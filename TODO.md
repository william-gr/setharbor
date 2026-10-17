# Pendências e verificação

- [x] Implementar 30 cenários E2E para os fluxos atuais.
- [x] Separar o pacote E2E e o certificado de fixtures do aplicativo pessoal.
- [x] Configurar workflow para PRs e branch main, em APIs 29 e 35.
- [x] Criar documentação CLAUDE.md.
- [x] Concluir execução e diagnóstico dos testes em emulador (30/30 em API 35; ver e2e/LOCAL_TEST_REPORT.md).
- [x] Publicar o repositório público MIT: https://github.com/william-gr/setharbor.
- [x] Confirmar matriz original de CI API 29/35: 30/30 em cada API, execução 38045908448.

Não marcar execução/CI como concluídos sem consultar os resultados reais.

- [x] Recuperar requisitos e catálogo da conversa em cloud.
- [x] Implementar catálogo offline e troca aleatória por similar só na sessão.
- [x] Preservar identidade, histórico, backups v1/v2 e bloquear troca com dados.
- [x] Testar regras de catálogo/sessão em JVM e compilar APK 1.5.
- [x] Passar quatro E2E focados em trocas, proteção de dados, backup e histórico.
- [x] Concluir regressão completa de 35 cenários e CI da versão 1.5 (35/35 em API 29 e 35; execução 38054423441).
- [x] Acrescentar 13 regressões JVM para catálogo, sessão e validação de ficha (26 testes totais).
- [x] Exigir cobertura por classe de lógica: 90% linhas / 80% branches, com relatório HTML/XML, gate em check/CI e falha com dados ausentes.
- [x] Criar workflow de APK da main mais recente, com versão YYYYMMDD do commit e artefato com SHA/proveniência.

- [x] Implementar protótipo de links de treino, preview/validação, prompt por compartilhamento e APK trial separado.
- [x] Receber relato do usuário de que o protótipo de links pareceu funcionar no celular.
- [x] Reduzir o prompt: guia/catálogo públicos, criar com texto curto e revisar com ficha opcional.
- [ ] Confirmar no celular real que o ChatGPT consulta o guia público e devolve um link funcional usando o prompt curto.

- [x] Permitir salvar séries feitas com peso/repetições opcionais e apresentar corretamente histórico/valores anteriores.
- [x] Adicionar pesquisa de execução no Google para exercícios planejados, trocados e personalizados.
- [x] Ocultar o link de execução nos detalhes do cartão, abrindo pelo ícone de informação, inclusive em exercícios personalizados.

## Pesquisa futura: sequência cíclica de treinos

- [x] Pesquisar organização por letras (A, B, C…) em vez de dias da semana, mantendo a ordem mesmo quando o usuário falta ou muda os dias de treino. Proposta em [docs/CYCLIC_WORKOUTS_PROPOSAL.md](docs/CYCLIC_WORKOUTS_PROPOSAL.md).

Comportamento a avaliar: A → B → C → A; faltar um dia não avança a sequência. O próximo treino deve depender do último concluído e salvo, não do calendário, e permanecer correto após reiniciar o app. Avaliar seleção manual, repetição/pulo de um treino e quando essas ações alteram o próximo sugerido. Preservar rascunhos, identidade dos exercícios, histórico e backups; estudar compatibilidade com fichas existentes (`days`), importação, links e instruções do ChatGPT. Esta tarefa é de pesquisa/proposta; a implementação fica para depois.

- [x] Implementar a sequência cíclica conforme a proposta: cursor por ID, seleção A/B/C, avanço ao salvar, migração, backup v4 e testes. Regra confirmada pelo usuário: sessões fora da ordem são extras e não avançam o cursor. 51 cenários locais cobertos em rodada completa de49 e verificação final de6; ver e2e/LOCAL_TEST_REPORT.md.

## Migração Flutter / iOS

- [x] Portar catálogo, contratos de dados e regras do app para Dart.
- [x] Gerenciar estado e dependências com Riverpod3, mantendo regras fora das telas.
- [x] Implementar telas compartilhadas Android/iOS e migração automática dos dados Android.
- [x] Preservar backupsv1–v4, links, histórico, rascunhos, trocas e sequência.
- [x] Validar26testes Flutter/gate90%linhas80%branches e3integrações em Android e iOS.
- [x] Verificar atualização Java→Flutter, falha real de disco, documentos, links e compartilhamento no emulador Android.
- [x] Concluir lint Android e2testes XCTest nativos iOS (arquivos, links e compartilhamento).
- [x] Confirmar CI da migração Flutter em AndroidAPI35 e iOS: [38918416649](https://github.com/william-gr/setharbor/actions/runs/38918416649), commit `f755776`, 26 testes Flutter, gate90%/80%, três integrações por plataforma e dois testes nativos iOS, sem skips.
- [ ] Retomar a validação AndroidAPI29 posteriormente, conforme preferência do usuário. A gravação e os três testes Dart passaram; o driver HTTPS falhou ao abrir/configurar o diálogo.
- [ ] Validar num iPhone real e configurar assinatura/distribuição iOS.
- [ ] Validar fluxo completo do ChatGPT no iPhone, incluindo leitura do guia e retorno pelo navegador/custom scheme.

## Ampliação do catálogo

- [x] Analisar cobertura dos 90 exercícios por grupo, equipamento, movimento, lateralidade e substituições. Ver [análise de 2026-10-17](docs/EXERCISE_CATALOG_AUDIT.md).
- [x] Revisar e implementar o primeiro lote de 25 exercícios (115 no total), preservando os 90 registros originais; fontes por novo exercício, perfis de equipamento e regressões de identidade/trocas/backups. Ver [revisão 2](docs/EXERCISE_CATALOG_REVISION_2.md).
- [ ] Definir registro de duração da série e resistência de elástico antes de ampliar exercícios dependentes dessas medidas.
- [ ] Avaliar preferências de equipamento, lateralidade e apoio nas substituições.
