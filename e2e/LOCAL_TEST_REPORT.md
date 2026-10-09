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
