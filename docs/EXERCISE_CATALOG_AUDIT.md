# Análise do catálogo de exercícios — 2026-10-17

**Conclusão:** 90 exercícios formam uma base útil para musculação em academia, mas a cobertura é desigual. A ampliação mais valiosa está em treino com pouco equipamento, movimentos unilaterais e famílias com poucas alternativas. Recomendo uma primeira seleção de **25 candidatos**, chegando a aproximadamente **115 exercícios após revisão**, acompanhada de melhorias na classificação. Essa quantidade é uma proposta de escopo, não uma meta científica de completude.

Este documento preserva a análise da revisão 1. A implementação posterior dos 25 candidatos está registrada em [Catálogo — revisão 2](EXERCISE_CATALOG_REVISION_2.md); os números abaixo continuam descrevendo a base original.

## Base e método

- Código analisado: `3c3937510d6fcad7d8e5278a6b0e21dac9618050`.
- Catálogo: revisão 1, schema 1; `app/src/main/assets/exercise-catalog.json` e `flutter_app/assets/exercise-catalog.json` têm bytes idênticos.
- SHA256 do catálogo: `597e941fa9ab4f70382a45a5a4577eecc15260ee1e1d676a6f2862c17b121e87`.
- Contagens calculadas diretamente do JSON; trocas calculadas pela mesma regra de `Catalog.alternatives` em `flutter_app/lib/domain/catalog.dart`.
- “Alternativa” significa outro ID com mesmo grupo, família, padrão e mecânica; o destino não pode ter `loadUnit=band` nem `mechanic=isometric`.
- Perfis de equipamento usam todos os requisitos declarados: `set(exercise.equipment) ⊆ equipamentos_disponíveis`. Não presumem que uma cadeira substitui um banco ou que existe ponto de ancoragem para elástico.
- As prioridades abaixo são avaliação de produto, sem dados de uso suficientes para afirmar quais exercícios os usuários mais procuram. As referências externas servem para ampliar o repertório e orientar a revisão editorial, sem importar seus textos ou imagens.

## Distribuição atual

Há **90 IDs**, **12 grupos**, **35 músculos**, **35 tipos de equipamento**, **22 padrões de movimento** e **25 famílias de substituição**.

| Grupo principal do catálogo | Exercícios | Leitura da cobertura |
| --- | ---: | --- |
| Costas | 16 | Sete puxadas, sete remadas e dois pulldowns isolados; variedade concentrada nesses movimentos |
| Peito | 13 | Cinco empurradas horizontais, quatro inclinadas e quatro crucifixos |
| Ombros | 11 | Desenvolvimento, elevação lateral e crucifixo inverso |
| Bíceps | 9 | Sete roscas supinadas e duas neutras |
| Quadríceps | 8 | Seis compostos e duas extensões de joelho; falta variedade unilateral e sem carga |
| Posteriores | 8 | Três RDLs e cinco flexoras |
| Tríceps | 6 | Três pushdowns e três extensões acima da cabeça |
| Panturrilhas | 6 | Quatro com joelho estendido e duas com joelho flexionado |
| Abdômen/tronco | 6 | Dois abdominais, duas pranchas e dois Pallof; quatro estão classificados como isometria |
| Glúteos | 3 | Dois hip thrusts e uma ponte com halter |
| Adutores | 2 | Máquina e cabo |
| Abdutores | 2 | Máquina e elástico |

Peito, costas, ombros e braços somam **55/90 (61,1%)**. Isso não exige distribuir a mesma quantidade por músculo: exercícios compostos participam de vários grupos. Por exemplo, embora só três estejam no grupo “glúteos”, o glúteo máximo aparece como músculo principal em seis exercícios e secundário em sete outros. Os rótulos são dados editoriais, não uma medida de estímulo ou eficácia.

A classificação de lateralidade contém **82 bilaterais e oito unilaterais**. Estes oito são remada com halter, remada no cabo, elevação lateral no cabo, agachamento dividido, extensora com elástico, flexora em pé, flexora com elástico e adução no cabo. Variações como búlgaro, step-up e RDL unilateral não estão representadas.

## Equipamento e treino em casa

| Equipamentos declarados disponíveis | Exercícios compatíveis | Grupos representados |
| --- | ---: | ---: |
| Peso corporal + colchonete | 4 | 2 |
| Anteriores + halteres | 12 | 8 |
| Halteres + colchonete + bancos reto e regulável | 22 | 10 |
| Peso corporal + colchonete + elástico | 13 | 8 |

Os quatro do primeiro perfil são flexão de braços, abdominal no solo e duas pranchas. **Não há agachamento sem carga, avanço sem carga, ponte sem carga nem panturrilha sem carga cadastrados.** Isso limita o planejamento de pernas em casa usando apenas IDs reconhecidos.

Com halteres e colchonete, os metadados não retornam exercício de costas ou tríceps. Existem remada unilateral e tríceps francês, mas suas entradas exigem banco. É preciso distinguir uma variação que realmente requer banco de outra em pé/curvada, em vez de simplesmente apagar um requisito do registro atual.

Dez exercícios usam elástico. A contagem de 13 do perfil com elástico é compatibilidade **de metadados**, não garantia prática: faltam requisitos explícitos de ancoragem e acessórios. O catálogo também não tem equipamento kettlebell, suspensão, caixa/step ou tornozeleira; incorporá-los deve acompanhar exercícios que justifiquem seu uso.

## Qualidade das substituições

| Alternativas automáticas por exercício | Quantidade de exercícios |
| ---: | ---: |
| 0 | 7 |
| 1 | 13 |
| 2 | 19 |
| 3 | 18 |
| 4 | 6 |
| 5 | 18 |
| 6 | 9 |

**20/90 (22,2%) têm no máximo uma alternativa.** Os sete sem nenhuma são:

- Pulldown braço estendido no cabo.
- Extensora na máquina.
- Cadeira abdutora.
- Prancha antebraços e prancha braços estendidos.
- Pallof no cabo e Pallof com elástico.

Nos três primeiros, a única outra entrada da família é um elástico, excluído como destino. Pranchas e Pallof estão classificados como isometrias, também excluídas. A extensora já aparece na ficha padrão de 31 posições: essa limitação afeta o programa inicial, não apenas possíveis fichas futuras.

A exclusão é aplicada ao **destino**. Assim, extensora com elástico pode oferecer extensora na máquina, mas a troca inversa não é oferecida. É uma consequência concreta da regra atual, não uma relação simétrica de equivalência.

As trocas não filtram equipamento disponível, lateralidade, apoio ou unidade de carga. Ao analisar cada exercício, 25 têm ao menos uma alternativa com lateralidade diferente; 53, com apoio diferente; e 73, com unidade de carga diferente. Isso não prova que essas trocas são incorretas: a interface informa a unidade e bloqueia trocas após registrar dados. Mostra, porém, que ampliar o catálogo sem revisar preferências pode aumentar sugestões pouco práticas, como uma máquina indisponível ou uma opção unilateral quando se espera execução bilateral.

Prioridade de produto: manter as famílias conservadoras e considerar disponibilidade de equipamento; permitir preferências de lateralidade/apoio quando necessário. Não afrouxar famílias só para eliminar todos os casos sem alternativa. Uma extensora não precisa ganhar um agachamento como substituto automático.

## Lacunas de classificação e registro

1. **Tempo e resistência:** a UI registra carga/repetições/conclusão. As notas das pranchas pedem tempo, mas não existe campo de duração da série; o cronômetro atual é de descanso. Elásticos têm rótulo próprio, porém não têm registro estruturado de resistência. Adicionar muitas isometrias, carries ou cardio antes de suportar suas medidas aumentaria essa incoerência.
2. **Movimentos ausentes:** não há categorias próprias para carregar peso caminhando, resistir à flexão lateral, rotação do ombro, elevação escapular, movimentos do punho ou dorsiflexão. Alguns pedem novos padrões/famílias e músculos, não apenas mais linhas de exercícios.
3. **Músculos:** não há entradas específicas para manguito rotador, flexores/extensores do punho ou tibial anterior. Trapézio superior, eretores e serrátil já existem, mas nunca aparecem como principais. Isso é um indicador editorial de cobertura; não significa que não sejam trabalhados nos exercícios existentes.
4. **Busca e aliases:** existem 43 aliases em 29 exercícios; 61 não têm aliases adicionais, embora todos tenham nomes PT/EN. Não foram encontradas colisões entre IDs após normalizar caixa/acentos. A ausência de colisão textual não resolve ambiguidades semânticas: “RDL / stiff”, “Flexora sentada/deitada”, “Desenvolvimento máquina / halteres” e “Panturrilha em pé ou sentado” hoje apontam para um ID específico.
5. **Identidade histórica:** novos nomes genéricos devem levar a uma escolha ou a instruções explícitas, preservando a resolução dos registros legados. Não remapear aliases antigos silenciosamente; nome alternativo do mesmo movimento continua alias, não vira exercício novo. Variações com equipamento, postura ou lateralidade relevantes podem justificar identidade própria após revisão.
6. **Rastreabilidade:** há quatro referências globais no JSON, mas nenhum vínculo de fonte por exercício; 90 registros compartilham apenas 29 textos distintos de notas. A revisão deve tornar as descrições específicas onde há diferenças relevantes e ligar fontes aos registros revisados.

## Primeira expansão proposta: 25 candidatos

Lista editorial proposta nesta análise e posteriormente implementada na revisão 2, com as decisões documentadas no relatório acima. Os candidatos abaixo não tinham entrada explícita na revisão 1. Não devem receber automaticamente a família de um exercício parecido pelo nome.

| Lote | Candidatos | Ganho esperado |
| --- | --- | --- |
| Base sem carga — 4 | Agachamento com peso corporal; avanço reverso sem carga; ponte de glúteos sem carga; panturrilha em pé sem carga | Cobrir pernas/glúteos em casa |
| Unilaterais — 4 | Agachamento búlgaro com halteres; step-up com halteres; passada caminhando com halteres; RDL unilateral com halter | Ampliar padrões e lateralidade |
| Halteres sem banco — 3 | Desenvolvimento em pé; remada curvada bilateral; supino no chão | Preencher limitações por equipamento |
| Quadril — 3 | Abdução no cabo; abdução deitada de lado; extensão de quadril no cabo | Ampliar abdutores e opções de extensão; revisar elegibilidade para trocas |
| Famílias pouco variadas — 3 | Pullover com halter; extensora unilateral na máquina; leg press unilateral | Candidatos a alternativas, com revisão de família, apoio e lateralidade |
| Trapézio/antebraço — 5 | Encolhimento com barra; encolhimento com halteres; rosca inversa com barra W; flexão de punho; extensão de punho | Introduzir movimentos hoje ausentes |
| Core por repetições — 3 | Dead bug; bird dog; abdominal reverso | Mais variedade além de crunch/prancha/Pallof; definir contagem por lado |

Se os 25 forem aprovados como registros distintos, o catálogo vai de 90 para **115**. Os candidatos unilaterais requerem orientação de contagem por lado; a entrada bilateral existente não deve ter seu ID reaproveitado.

**Etapa seguinte, após suporte de métricas:** prancha lateral, carries, isometrias adicionais e registro de elástico. Kettlebells, terra convencional, agachamento frontal, paralelas, movimentos de manguito e outras máquinas podem formar lotes posteriores conforme pedidos reais e cobertura. Sem dados de uso, não há base para afirmar que 200 ou 500 exercícios seriam o tamanho certo.

## Critérios para executar a expansão

- Preservar os 90 IDs existentes, backups e identidade do histórico; aumentar a revisão do catálogo e validar todas as referências.
- Dar a cada novo exercício nome PT/EN, aliases sem ambiguidade nova, equipamento/acessórios necessários, unidade, lateralidade, notas e fonte específica.
- Revisar cada família afetada e as trocas resultantes; aceitar “sem alternativa” quando não houver substituto adequado.
- Recalcular os perfis acima e confirmar que as lacunas priorizadas ganharam opções reais.
- Manter os assets Android/Flutter idênticos e regenerar guia/JSON públicos do ChatGPT. O prompt curto permanece curto; o catálogo continua no guia.
- Testar identidade, aliases, ausência de colisões, restrições de trocas e compatibilidade do catálogo novo com fichas/backups antigos. Não usar apenas o número de exercícios como critério de aprovação.
- Manter curadoria original MIT e referências externas, sem copiar descrições ou imagens de terceiros para os assets.

## Referências consultadas

As contagens e falhas de cobertura acima vêm do repositório. A recomendação de lotes é nossa avaliação editorial. A [biblioteca ACE](https://www.acefitness.org/resources/everyone/exercise-library/) organiza movimentos também por equipamento, experiência e áreas como antebraço, manguito e tibial, ajudando a identificar dimensões que faltam no catálogo.

O [agachamento sem carga](https://www.acefitness.org/resources/everyone/exercise-library/135/bodyweight-squat/) e o [bird dog](https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/) são exemplos documentados pela ACE que faltam aqui. O artigo da ACE [Glute Goals](https://www.acefitness.org/resources/pros/expert-articles/9061/glute-goals-an-evidence-based-glute-workout/?topicScope=workouts) inclui step-ups e lunges entre os movimentos discutidos; isso ajuda a selecionar candidatos, sem estabelecer equivalência automática ou ranking de eficácia. O [farmer’s carry](https://www.acefitness.org/resources/everyone/exercise-library/359/farmer-s-carry/) exemplifica uma expansão que demanda revisar o registro de distância/tempo.

A [biblioteca NASM](https://www.nasm.org/resource-center/exercise-library), já referenciada pelo catálogo, também foi consultada, mas a página acessível não forneceu detalhes suficientes para uma comparação quantitativa. Não foi usada para justificar números ou anatomia específica.
