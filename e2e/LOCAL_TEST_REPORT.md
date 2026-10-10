# Verificação local — 2026-10-08

## Resultado

**30 de 30 cenários E2E passaram**, sem falhas, erros ou skips, em uma execução completa de `python3 e2e/run.py` (2164,456 segundos, cerca de 36 minutos).

Ambiente: macOS Apple Silicon, JDK 17 (Temurin), Gradle 8.9, Android SDK 35 e emulador Google APIs Android API 35 ARM64 com aceleração e animações desativadas. Pacote testado: `com.william.treino.e2e`. Nenhum aparelho físico foi utilizado.

- `./gradlew assembleDebug assembleE2e lintDebug`: passou. Lint sem erros; seis avisos permanecem sobre internacionalização, target SDK e uma gravação síncrona de preferências.
- `python3 -m py_compile e2e/*.py` e `git diff --check`: passaram.
- Inspeção dos APKs: CA/configuração de rede das fixtures presentes somente no APK E2E e ausentes no APK debug pessoal.
- Importação, exportação, restauração e HTTPS exercitados pela UI e por arquivos/conexões reais.

## Correções feitas durante o diagnóstico

- Substituídos valores numéricos de orientação por `LinearLayout.VERTICAL`, corrigindo três erros de lint.
- Driver aguarda o foco e confirma o texto digitado antes de fechar o teclado, evitando comandos antes de a UI processar o toque.
- Seletores de botões aceitam a capitalização nativa do Android; seletores de documentos aceitam os pacotes AOSP e Google do DocumentsUI.

O impedimento anterior de System UI ANR ocorreu em um emulador API 29 sem aceleração. A execução concluída acima utilizou outro emulador, acelerado. API 29 não foi executada localmente nesta continuação; a matriz de CI cobre APIs 29 e 35.

## Evidências

Resultados por cenário: `e2e/artifacts/results.json`, com `complete: true`, `tests_run: 30` e `success: true`. Screenshots, XML e logcat ficam em `e2e/artifacts/<cenário>/`. Artefatos locais são ignorados pelo Git; CI publica seus próprios resultados e relatórios.

Esta aprovação local não equivale a uma aprovação da matriz de CI. Consulte a execução real do GitHub Actions para esse resultado.

## Diagnóstico de CI — 2026-10-09

Na execução https://github.com/william-gr/setharbor/actions/runs/37833596780, API 35 passou 30/30; API 29 passou 27/30. Falhas: 11/27 consultaram XML antigo enquanto a screenshot mostrava o cronômetro funcionando; 30 tentou tocar um nome de arquivo com bounds `[0,0][0,0]`.

Correções: dumps exigem arquivo novo e confirmação do UI Automator; nós sem área visível são ignorados; cronômetro só chama setText quando o texto muda, evitando eventos redundantes a cada 250 ms. Build/lint e sintaxe passaram; cenários 11, 27 e 30 passaram localmente em API 35 em 229,641 segundos. A nova matriz de CI ainda precisa confirmar o resultado em API 29.

Na execução https://github.com/william-gr/setharbor/actions/runs/37928823706, API 29 passou **30/30**, confirmado no results.json do artefato; API 35 passou 29/30. A falha restante (18) reproduziu XML reciclado da lista/grade do DocumentsUI, com arquivo visível na screenshot mas ausente no XML.

O driver agora seleciona documentos pela busca real de nome no picker e identifica o título pelo resource-id `android:id/title`. Cenários 18 e 30 passaram em uma pasta Downloads com 12 arquivos adicionais (297,255 segundos); o seletor final de título passou no cenário 13 (66,299 segundos), em API 35 local. Não há injeção de resultado de Activity nem acesso a preferências para selecionar arquivos. Nova execução da matriz pendente.

Na execução https://github.com/william-gr/setharbor/actions/runs/37961278915, API 29 mostrou que o campo de busca é EditText, enquanto API 35 usa AutoCompleteTextView. O seletor agora usa o resource-id search_src_text em ambos, verificado contra os XMLs reais. API 35 passou as importações/restaurações, mas houve um erro ADB na limpeza de dados antes do cenário 28; logcat mostrou conexão adbd interrompida e a exceção antiga não incluía stderr.

Preparação agora força a parada antes de limpar, exige retorno Success e permite uma única repetição da limpeza somente para erros reconhecidos de transporte; stderr/stdout são preservados. Permissões e assertions não são repetidas. Cenários 13/27/28 passaram localmente com esse driver (173,495 segundos); verificação isolada confirmou que transporte fechado permite a repetição e erro de permissão falha imediatamente. Nova matriz pendente.

Na execução https://github.com/william-gr/setharbor/actions/runs/37974858007, API 35 passou 30/30. API 29 revelou falhas da busca do picker AOSP: caracteres perdidos durante filtragem e crash de SearchFragment (`Can not perform this action after onSaveInstanceState`) em onDestroy/onSearchViewFocusChanged. O driver usa novamente a navegação normal no AOSP, que passou 30/30 na execução 37928823706, e mantém busca real no Google DocumentsUI, aprovada 30/30 em API 35. Nova matriz combinando os dois caminhos pendente.

## Catálogo — 2026-10-10

Requisitos e dados recuperados da continuação em cloud. Catálogo com 90 exercícios, 12 grupos e 35 músculos; troca aleatória por família só na sessão, bloqueio com dados, identidade de movimento separada da posição, snapshots reais e backups v3 (aceitando v1/v2).

13 testes JVM passaram, build/lint de debug e E2E passou sem erros. Os quatro cenários novos 31–34 passaram em API 35 em 621,166 segundos, antes do ajuste final de exportação v3 e nomes explícitos na ficha. A regressão final com 34 cenários e o backup v3 está em andamento; ainda não está aprovada. Os artefatos locais ficam em e2e/artifacts/catalog-targeted e catalog-full (ignorados pelo Git).
