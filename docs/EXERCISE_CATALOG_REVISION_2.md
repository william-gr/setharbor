# Catálogo — revisão 2

Implementação do primeiro lote da [análise de cobertura](EXERCISE_CATALOG_AUDIT.md), em 2026-10-17. O catálogo passa de **90 para 115 exercícios**, mantendo schema 1, os 90 registros originais completos e seus aliases. Android e Flutter recebem assets idênticos. O projeto e a curadoria original continuam gratuitos e MIT; referências externas não transferem licenças de imagens ou textos para o projeto.

## Exercícios incluídos

- Sem carga: agachamento, avanço reverso, ponte de glúteos e panturrilha em pé.
- Unilaterais com halteres: búlgaro, step-up, passada caminhando e RDL com um halter contralateral.
- Halteres sem banco: desenvolvimento em pé, remada curvada bilateral e supino no chão.
- Quadril: abdução no cabo, abdução deitada de lado e extensão no cabo.
- Outras variações: pullover com halter, extensora unilateral e leg press unilateral.
- Trapézio/antebraço: encolhimentos com barra e halteres, rosca inversa com barra W, flexão e extensão de punho com halter.
- Core: dead bug e bird dog dinâmicos por repetições, abdominal reverso.

Total: **13 grupos, 37 músculos, 37 equipamentos, 25 padrões e 34 famílias**. O grupo Antebraços e os termos flexores/extensores do punho foram acrescentados; caixa/step e tornozeleira para cabo são requisitos explícitos nos exercícios correspondentes. Há agora **22 exercícios classificados como unilaterais**, contra oito na revisão 1. Nesses novos registros, as notas especificam repetições por lado e unidade da carga. Os registros continuam aceitando séries concluídas sem peso/repetições.

## Revisão das famílias

Estas são decisões de curadoria do SetHarbor; não representam equivalência de carga ou uma prescrição de substituição para cada pessoa.

- Extensora bilateral ganha a extensora unilateral como alternativa, preservando extensão isolada do joelho. Todas as 31 posições da ficha padrão passam a ter alguma alternativa.
- Cadeira abdutora ganha abdução no cabo e deitada de lado. Novos acessórios e lateralidade aparecem nos detalhes, mas a troca ainda não filtra equipamento disponível.
- Encolhimentos com barra/halteres compartilham a nova família de elevação escapular; não são remadas ou elevações laterais.
- Pullover tem família própria no grupo Peito, com dorsal secundário. A [referência do movimento](https://www.strengthlog.com/dumbbell-pullover/) descreve participação de ambos; não foi presumida equivalência com pulldown no cabo. Este último continua sem alternativa automática elegível.
- Kickback no cabo, rosca pronada e os dois movimentos do punho têm famílias próprias. O kickback não passa a substituir hip thrust; flexão do punho não substitui extensão.
- Dead bug, bird dog e abdominal reverso têm famílias distintas de crunch, prancha e Pallof. Os dois primeiros representam execução dinâmica contada por lado, com estabilização do tronco, conforme as referências de [dead bug](https://www.strengthlog.com/dead-bugs/) e [bird dog](https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/). Não há novo campo de duração nesta revisão.
- As demais variações seguem as famílias existentes de empurradas, remadas, compostos de quadríceps, RDL, ponte e panturrilha em pé. Apoio, amplitude, lateralidade e carga podem diferir; isso aparece nas notas.

O total sem alternativa automática passa de sete para **13**: duas lacunas anteriores foram resolvidas (extensora/abdutora), enquanto oito movimentos novos ficam isolados por classificação conservadora. Não foram relaxadas as exclusões de destinos com elástico ou isometria para melhorar essa contagem.

## Cobertura por equipamento

Mesmo método da auditoria: todos os requisitos do exercício devem estar no conjunto disponível. As contagens descrevem metadados, não uma recomendação de rotina.

| Perfil | Revisão 1 | Revisão 2 | Grupos na revisão 2 |
| --- | ---: | ---: | ---: |
| Peso corporal + colchonete | 4 | 12 | 6 |
| Anteriores + halteres | 12 | 26 | 10 |
| Anteriores + bancos reto e regulável | 22 | 40 | 12 |
| Peso corporal + colchonete + elástico | 13 | 21 | 10 |

Os exercícios de punho desta revisão são sentados em banco; o step-up exige caixa/step; o búlgaro exige banco; os novos movimentos no cabo exigem tornozeleira. Não foram removidos requisitos dos exercícios antigos para inflar as contagens. A ancoragem dos exercícios antigos com elástico ainda merece revisão.

## Identidade, fontes e guia público

Cada novo exercício tem nomes PT/EN, aliases sem colisão após normalização, notas específicas e `sourceIds` apontando para referências no JSON. As referências foram consultadas para os movimentos; equipamentos, unidade de registro, contagem por lado e agrupamento são escolhas editoriais da variação cadastrada, não uma cópia integral da fonte. Não foram importadas imagens ou descrições de terceiros.

A fixture `flutter_app/test/fixtures/catalog_revision1_identity.json` congela nomes, aliases e classificação de troca dos 90 IDs anteriores. As classificações antigas são preservadas porque mudá-las pode invalidar trocas em backups existentes. Nomes legados genéricos continuam resolvendo para o ID anterior; novas fichas devem preferir `catalogId` explícito.

O gerador do guia agora inclui notas na tabela e orienta a considerar acessórios e repetições por lado. O pedido compartilhado pelo app continua curto e aponta para a página, sem embutir o catálogo. O JSON público gerado é idêntico ao asset; a publicação ocorre pelo workflow de Pages. Instalações antigas precisam atualizar o app para reconhecer os novos IDs nos detalhes/trocas; referências desconhecidas continuam sendo aceitas nas fichas.

## Verificação

- Flutter: análise estática e 30 testes passaram, incluindo quatro regressões da expansão: identidade antiga, todas as trocas antigas elegíveis em backups v3/v4, fontes/resolução dos 25 novos registros e histórico sem medições, equipamentos e exclusões de famílias.
- Gate de cobertura mantido em 90% de linhas/80% de branches por arquivo de lógica; catálogo com 100%/100%. Os dois testes negativos do gate passaram.
- Leitor Java legado: 44 testes JVM e `coreCoverageVerification` passaram. A expectativa de extensora sem alternativas foi substituída pela alternativa unilateral específica.
- Guia canônico e seis testes web passaram. Assets Android/Flutter idênticos; comparação com a revisão 1 confirmou os 90 registros completos inalterados.
- Integração Android API35: três testes passaram no emulador, sem falhas ou skips; APK E2E compilado com os novos assets e lint Android aprovado. E2E nativo de documentos/rede e iOS não foram reexecutados localmente para esta mudança de dados; o workflow multiplataforma os executa após o push.

## Próximas etapas

Continuam em TODO: registro de duração/resistência de elásticos, preferências de equipamento/lateralidade/apoio nas trocas e lotes adicionais conforme necessidades reais. Esta revisão implementa os 25 candidatos e sua classificação, sem alterar esses contratos de registro ou criar um seletor de equipamento.
