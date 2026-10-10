# SetHarbor — documentação para agentes

## Objetivo

Aplicativo Android gratuito e open source (MIT) para registrar treinos de musculação. A ficha de exemplo tem cinco dias e pode ser substituída por qualquer programa compatível. O app registra carga/repetições, oculta séries concluídas, conserva histórico, cronometra descanso e recebe fichas atualizadas sem recompilar.

## Arquitetura e arquivos

- `app/src/main/java/com/william/treino/MainActivity.java`: interface com widgets Android, persistência, histórico, seletor de documentos, backup e atualização HTTPS.
- `app/src/main/java/com/william/treino/WorkoutPlan.java`: validação de fichas JSON.
- `app/src/main/java/com/william/treino/ExerciseCatalog.java`: catálogo offline e famílias de substituição.
- `app/src/main/java/com/william/treino/ExerciseSession.java`: trocas por sessão, validação e snapshots.
- `app/src/main/assets/exercise-catalog.json`: 90 exercícios com IDs estáveis, grupos, músculos e equipamentos.
- `docs/EXERCISE_CATALOG.md`: contrato e regras de identidade/troca.
- `app/src/main/assets/default-plan.json`: ficha original, usada na primeira abertura e na migração de histórico antigo.
- `app/src/main/res`: tema e ícone vetorial.
- `app/src/e2e`: sobreposição exclusiva do APK E2E para confiar no certificado HTTPS das fixtures locais.
- `e2e/android_ui.py`: interação com o dispositivo via ADB e XML do UI Automator.
- `e2e/test_workout_app.py`: 35 cenários E2E.
- `e2e/run.py`: execução e relatório JSON.
- `.github/workflows/android-e2e.yml`: build/lint e E2E em PRs e pushes na main.

Não há framework de UI externo, conta de usuário, banco remoto ou integração MCP no aplicativo. A ficha pode vir de um servidor HTTPS; o histórico permanece local.

## Build

JDK 17, Gradle 8.9, Android Gradle Plugin 8.7.3, compile/target SDK 35, min SDK 26.

VersionCode e versionName usam a data de committer do commit compilado, YYYYMMDD, preservando a data registrada no Git independentemente do relógio/fuso da máquina de build. Commits no mesmo dia têm a mesma versão; nomes de APK incluem SHA. Archives sem .git exigem -PappVersionDate=YYYYMMDD (validado como data real). O workflow build-apk.yml compila a main mais recente em push/manual, roda cobertura/lint e publica somente APK debug do app pessoal (não E2E) com proveniência e SHA256. Artefatos expiram em 30 dias; assinatura de CI é debug, não a chave pessoal.

```bash
./gradlew testDebugUnitTest assembleDebug lintDebug
./gradlew assembleE2e
```

`./gradlew coreCoverageVerification` executa os testes JVM, gera relatório JaCoCo HTML/XML e exige 90% de linhas e 80% de branches **por classe** de lógica. Inclui automaticamente novas classes; exclui somente MainActivity/suas classes internas e classes Android geradas. A Activity é coberta pelos E2E reais, não pelo percentual JVM. `check` e CI executam a verificação; ausência de classes, testes ou dados de execução falha. Relatórios em `app/build/reports/jacoco/coreCoverageReport/`. Não reduza os limites ou exclua lógica para fazer o gate passar.

Application ID preservado por compatibilidade: `com.william.treino`. Pacote de testes: `com.william.treino.e2e`.

A assinatura debug padrão é usada quando a chave pessoal não existe. `signing/personal-debug.jks` é opcional, local e ignorada pelo Git; não a versione. Para atualizar a instalação pessoal preservando dados, mantenha a assinatura original e aumente `versionCode`. APKs de CI usam outra chave debug e não substituem automaticamente a instalação pessoal.

## Persistência e invariantes

SharedPreferences `training` guarda:

- `plan`: ficha ativa em JSON; a ausência usa a ficha original.
- `history`: array de sessões. Cada sessão nova tem `date`, `day`, `phase`, `sets` e uma cópia da `plan` usada.
- `draft<N>`: rascunho por índice do dia. As chaves de série são `<índice-exercício>_<índice-série>kg`, `reps` e `done`.
- `draft<N>.exerciseOverrides`: mapa de ID da posição para catalogId, exclusivo da sessão. Impede atualização da ficha enquanto existir.
- `day` e `phase`: seleção atual.
- `planUrl`: URL opcional de atualização, excluída dos backups.

Não interprete sessões antigas usando a ficha atual. A cópia da ficha no histórico preserva nomes, ordem e quantidades antigas. Na migração, registros sem `plan` recebem a ficha original. A consulta de último desempenho usa catalogId quando conhecido, com compatibilidade de IDs legados/personalizados. O campo id continua sendo o ID da posição na ficha.

Trocar a ficha é bloqueado enquanto houver rascunhos, para não misturar posições entre programas. Não descarte dados ao resolver esse bloqueio. Ocultar uma série marcada altera apenas a apresentação; os valores continuam no rascunho e só séries marcadas entram no histórico.

Semana 1: no máximo duas séries por exercício, respeitando exercícios de uma série. Semana 2/Normal: volume da ficha. Zero kg é válido para peso corporal; repetições precisam ser maiores que zero.

## Contrato da ficha

```json
{
  "format": "meu-treino-plan",
  "schemaVersion": 1,
  "revision": 2,
  "title": "Nome da ficha",
  "days": [{
    "id": "day-0",
    "name": "Segunda",
    "focus": "Peito e quadríceps",
    "exercises": [{
      "id": "legacy-0-0",
      "catalogId": "barbell-bench-press",
      "name": "Supino reto barra",
      "sets": 3,
      "reps": "6–8"
    }]
  }]
}
```

Revisão positiva, 1–7 dias, 1–20 exercícios por dia, 1–10 séries. IDs de dias são únicos; IDs de exercícios são únicos na ficha inteira. Preserve IDs nas revisões do mesmo exercício para manter a associação do último desempenho. Não reutilize um ID para um movimento diferente.

Importação lê até 1 MB, valida antes de salvar e pede confirmação. Atualização HTTPS verifica ao abrir, aceita resposta HTTP 200 sem redirecionamento e só aplica revisões maiores quando não há rascunho. Falhas de rede preservam a ficha offline. Não há servidor ou endpoint pré-configurado.

## Backups

Backup v3 inclui `version`, `plan`, `history`, `phase` e rascunhos dos dias. Restaurar substitui o estado mediante confirmação. Backup v1 é aceito e restaura a ficha original; v2 também continua aceito. V3 impede que versões antigas ignorem trocas em rascunhos e atribuam cargas ao exercício errado. Mantenha essa compatibilidade ao mudar o formato; não remova campos ou histórico silenciosamente.

## Testes E2E

Use um emulador, nunca o celular pessoal. Os testes recusam dispositivos físicos e limpam apenas o pacote E2E. Python padrão basta, sem pip.

```bash
E2E_APK="$PWD/app/build/outputs/apk/e2e/app-e2e.apk" \
ANDROID_SERIAL=emulator-5554 \
python3 e2e/run.py
```

O servidor HTTPS local usa porta dinâmica e `adb reverse`. CA e chave de fixtures são exclusivamente de desenvolvimento e só a CA de `src/e2e` é confiada no APK E2E. Não inclua essa confiança no APK pessoal.

O seletor de documentos é real: arquivos são copiados para Downloads, importados pela UI e exportados para documentos reais. Os testes não substituem Activities ou SharedPreferences por mocks. Preserve as descrições acessíveis dos campos e seletores usadas pelo driver.

Resultados ficam em `e2e/artifacts/results.json`; screenshots, XML e logcat ficam por cenário. Examine esses arquivos antes de atribuir uma falha ao produto. Consulte `e2e/README.md` para cobertura, pré-requisitos e execução individual.

## CI

Eventos: todos os PRs, push na `main` e workflow_dispatch. Matriz API 29/35, Ubuntu com KVM, build/lint antes dos testes. Artefatos são publicados mesmo em falha. Não use segredos ou permissões de escrita para os jobs de PR.

## Limitações conhecidas

- Cronômetro para uso com o app aberto; não é um alarme confiável em background.
- Ficha original embutida, mas atualizações independem do APK por JSON/HTTPS.
- Dados do histórico não são sincronizados com servidor nem enviados por atualização de ficha.
- Automatizar publicação de fichas por MCP exige uma integração externa acessível ao cliente de IA; o app não oferece esse canal.

## Regras ao modificar

O usuário prefere merge/push direto na `main` após todos os testes passarem. Não abra PR sem pedido explícito.

1. Preserve histórico, migração de backups e assinatura das atualizações pessoais.
2. Mantenha fixtures e certificados fora do build pessoal.
3. Execute build/lint e E2E apropriados; relate explicitamente testes que não puder executar.
4. Não diga que a suíte passou apenas porque scripts ou APKs compilaram.
5. Atualize esta documentação, README e fixtures quando mudar contratos ou comportamento.

## Catálogo e trocas

Trocar por similar escolhe imediatamente outra opção aleatória da mesma família, grupo, movimento e mecânica, excluindo o exercício atual. Sem busca, seletor ou confirmação. Não trocar se qualquer série da posição tiver carga/reps ou check (incluindo séries ocultas). A ficha ativa não muda; rascunhos e backups guardam a troca; o snapshot do histórico guarda o exercício real. Ao salvar o treino, a próxima sessão volta à ficha ativa. Não misture cargas por posição; compare a identidade do movimento. CatalogId desconhecido é válido em uma ficha, mas não habilita substituições.
