# Testes E2E — SetHarbor

A suíte usa `unittest` e ADB, sem dependências Python externas. Ela abre o APK instalado, toca e preenche a interface, navega no seletor real de documentos, reinicia o processo e consulta o resultado pela interface. Não injeta resultados de Activities nem acessa diretamente SharedPreferences.

## Execução

Pré-requisitos: Python 3.10+, JDK 17, Android SDK 35/build-tools e um emulador Android com ADB habilitado (API 29 ou superior recomendado). No projeto:

```bash
./gradlew assembleE2e
ADB="$ANDROID_SDK_ROOT/platform-tools/adb" \
ANDROID_SERIAL=emulator-5554 \
E2E_APK="$PWD/app/build/outputs/apk/e2e/app-e2e.apk" \
python3 e2e/run.py
```

No Windows, use `gradlew.bat assembleE2e` e configure essas variáveis antes de executar Python. Desative animações no emulador para reduzir flutuações. O script também pode usar `adb` já presente no PATH.

Os testes recusam aparelhos físicos e usam somente `com.william.treino.e2e`; cada cenário limpa os dados desse pacote, nunca de `com.william.treino`. O APK E2E e os certificados não precisam ser instalados no seu celular pessoal. Use um emulador descartável, sem dados pessoais.

## Rede e arquivos reais

O servidor HTTPS de fixtures roda em uma porta local dinâmica e é alcançado pelo emulador via `adb reverse`. A CA de teste é confiada somente pelo APK E2E e somente nos domínios locais configurados. A chave em `fixtures/tls-key.pem` é exclusivamente uma chave de teste de desenvolvimento, descartável, sem uso de produção. `src/e2e` não faz parte do APK normal.

Fixtures JSON são copiadas para Downloads; importar/restaurar usa o DocumentsUI do Android. Exportar backup escreve um documento real, cujo JSON é lido para conferir integridade. Os testes não simulam o funcionamento do seletor.

## Cobertura de cenários

| Testes | Comportamento verificado |
|---|---|
| 01–03 | Cinco dias, readaptação/volume completo e persistência dos valores após reinício |
| 04–05 | Ocultar série marcada, revelar, desfazer check e preservar check após reinício |
| 06–10 | Treino vazio, dados inválidos, cancelar conclusão, histórico/últimos valores e somente séries marcadas |
| 11, 26–27 | Iniciar/parar/trocar cronômetro, término de contagem e rotação com rascunho |
| 12–15 | Importar nova ficha, preservar histórico anterior, cancelar, bloquear durante sessão e rejeitar arquivos inválidos |
| 16–19, 30 | Backup completo com rascunho/histórico/ficha, cancelar, compatibilidade v1 e rejeitar backup inválido |
| 20–24 | HTTPS real, atualização ao abrir, adiar durante rascunho, ignorar revisão antiga, falhas HTTP/JSON/redirecionamento e desativar sincronização |
| 25, 28–29 | Persistir dia/modo, cancelar seletores de arquivos, carga zero válida e repetições zero inválidas |

Isso cobre os fluxos funcionais atualmente presentes no app. Não equivale a cobertura de todos os aparelhos, versões Android, idiomas, leitores de tela ou condições possíveis de conectividade.

## Resultados e diagnóstico

`artifacts/results.json` contém resultado e duração por cenário quando executado com `run.py`. Cada cenário também guarda XML da tela, screenshot e logcat em `artifacts/<nome-do-teste>/`. Esses arquivos podem conter os dados fictícios de treino usados pelos testes. A execução retorna código diferente de zero quando há falha.

Para um cenário específico, execute, com as mesmas variáveis:

```bash
python3 -m unittest discover -s e2e -p 'test_*.py' -k test_12 -v
```

A automação aceita os pacotes AOSP e Google do DocumentsUI, os rótulos comuns de Downloads e salvar em inglês/português e a capitalização de botões nativos do Android. Para imagens de emulador que mudem esses rótulos, ajuste `android_ui.py`. O driver descarta dumps antigos quando o UI Automator falha e ignora nós sem área visível, inclusive arquivos fora da área rolada no DocumentsUI. Para selecionar um documento, usa a busca real por nome, identifica o campo pelo resource-id search_src_text (a classe varia entre versões) e o elemento de título do arquivo; isso evita inconsistências de acessibilidade em listas/grades recicladas durante rolagem. O driver aguarda o foco dos campos e confirma o texto digitado antes de fechar o teclado; comandos ADB concluídos não garantem que a UI já processou o toque. Antes de tratar uma falha como defeito do produto, examine XML e screenshot para diferenciar problemas da automação.

## CI nos PRs e na main

`.github/workflows/android-e2e.yml` executa em todo pull request, push na `main` e disparo manual. Compila os APKs e faz lint, depois executa todos os cenários em uma matriz Android API 29 e 35 com aceleração KVM. Os resultados, screenshots, logs, relatórios e APKs ficam como artefatos por 14 dias, mesmo quando o job falha. As execuções anteriores da mesma referência são canceladas ao chegar um novo commit.

O workflow não depende de segredo para rodar testes em PRs de forks. A chave pessoal de atualização do aplicativo não é versionada; no CI o Gradle gera sua assinatura debug padrão. Portanto, o APK gerado no CI não substitui a instalação pessoal assinada pela chave original sem configurar essa chave separadamente. Não desinstale o aplicativo pessoal para instalar o APK E2E: são pacotes distintos.

A preparação força a parada do pacote E2E e exige confirmação de limpeza dos dados. Apenas uma falha reconhecida de transporte ADB durante essa limpeza idempotente permite uma segunda tentativa; falhas de permissão e de assertions continuam falhando. stdout/stderr de comandos ADB com erro ficam em `adb-error.json` nos artefatos.
