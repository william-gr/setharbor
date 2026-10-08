# Meu Treino — Android

Aplicativo pessoal de William. Android 8 ou superior. Funciona offline. A permissão de internet é usada somente se você configurar uma URL para atualizar a ficha.

## Uso

- Escolha o dia de segunda a sexta. O programa contém os 31 exercícios da ficha original, com séries e faixas de repetições.
- Selecione Semana 1 (2 séries por exercício, RIR 3–4), Semana 2 (volume completo, RIR 2) ou Normal (volume completo, RIR 1–2).
- Registre carga em kg e repetições reais e marque cada série concluída. Para halteres, use carga por halter; para exercícios sem carga externa, registre 0 kg. Em máquinas assistidas, mantenha uma convenção consistente para registrar a assistência.
- O rascunho é salvo enquanto você preenche. Finalize com “Concluir e salvar treino”. Apenas séries marcadas entram no histórico. A conclusão limpa o rascunho daquele dia.
- O cartão de cada exercício mostra os últimos valores registrados. O histórico lista todas as sessões concluídas.
- O cronômetro oferece 60, 90 e 120 segundos. O aviso sonoro funciona enquanto o aplicativo permanece aberto; ele não é um alarme confiável com o aplicativo fechado ou em segundo plano.
- Exporte backups periodicamente. Restaurar um backup substitui o histórico e os rascunhos atuais, mediante confirmação. Desinstalar pode apagar seus registros.

## Instalação do APK

Baixe Meu-Treino.apk no celular e abra. Se solicitado, permita que o aplicativo usado para abrir o arquivo instale aplicativos dessa origem. Esta versão usa assinatura de depuração para instalação pessoal; não é uma publicação na Play Store.

## Compilação

Abra este diretório no Android Studio e instale SDK 35. JDK 17, Android Gradle Plugin 8.7.3 e Gradle 8.9. Execute `./gradlew assembleDebug lintDebug` (Windows: `gradlew.bat assembleDebug lintDebug`). O APK fica em `app/build/outputs/apk/debug/app-debug.apk`.

O projeto não tem dependências de bibliotecas externas de interface. Usa widgets Android, SharedPreferences para armazenamento local e JSON para backup. Não contém conta, sincronização de histórico entre dispositivos nem acesso remoto pelo ChatGPT. A ficha pode ser atualizada por importação ou URL HTTPS.

## Validação desta entrega

Código Java compilado, recursos Android empacotados, DEX gerado e assinatura APK v2/v3 verificada. Manifesto confirmado: pacote com.william.treino, Android mínimo 26 e alvo 35. A compilação foi realizada diretamente com ECJ e as ferramentas do SDK porque a resolução de dependências do Gradle estava indisponível neste ambiente. Não foi possível executar testes em aparelho ou emulador; a interface e o fluxo completo precisam desse teste. A chave de depuração pessoal está incluída para permitir atualizações que preservem o aplicativo instalado; não use essa chave para publicação comercial.

## Versão 1.1

Ao marcar uma série, a linha fica oculta. Um contador informa quantas séries foram concluídas. Use “Mostrar séries concluídas” no exercício para conferir cargas, editar ou desmarcar uma série. As séries marcadas permanecem gravadas e entram no histórico ao concluir o treino.

## Versão 1.2 — fichas independentes do APK

“Importar ficha de treino” recebe arquivos no formato Ficha-Treino.json. A importação valida formato, revisão, dias, exercícios e séries. O histórico guarda uma cópia da ficha usada em cada sessão, preservando nomes e ordem antigos. Os IDs de exercícios devem permanecer iguais nas revisões para que os últimos valores continuem associados ao mesmo movimento. Não reaproveite um ID para outro exercício.

Importar uma ficha não apaga o histórico. Para evitar misturar uma sessão iniciada com outra ficha, conclua todos os treinos em andamento antes da troca. A Semana 1 usa no máximo duas séries por exercício e respeita exercícios que tenham apenas uma série.

“Atualização online” aceita uma URL HTTPS que responda diretamente com o JSON (sem redirecionamento). Ao abrir o app, ele verifica se a revisão publicada é maior e aplica a ficha se não houver treino em andamento. Se houver, a ficha atual permanece e a próxima abertura tenta novamente. “Salvar e verificar” permite conferir manualmente. Desativar remove a URL. Não há servidor pré-configurado nesta entrega, e o ChatGPT não tem acesso de escrita automático a um servidor do usuário. O histórico nunca é enviado por essa funcionalidade.

O servidor da ficha pode ser local na LAN, desde que tenha HTTPS com certificado confiável no aparelho e esteja acessível pelo celular. MCP é um canal separado para um cliente de IA publicar alterações; o app atual busca a ficha por HTTPS e não implementa um servidor MCP. Não existe ligação direta entre esta conversa e o Android.

Backup v2 inclui a ficha ativa, histórico e rascunhos. Backups v1 continuam aceitos e recuperam a ficha original. A URL de sincronização não é incluída em backups.

Validação adicional: oito verificações executadas no validador de fichas (ficha original, uma série, zero séries, excesso de séries, IDs duplicados, versão incompatível, lista vazia e independência de cópias). APK 1.2 compilado e assinatura verificada; o fluxo visual e a atualização por rede ainda precisam de teste no aparelho.

## Testes e integração contínua

Há 30 cenários E2E em `e2e/test_workout_app.py`, executados pela interface Android com ADB e Python padrão. Instruções e matriz de cobertura: `e2e/README.md`. O APK de testes tem applicationId distinto e não limpa os dados do aplicativo pessoal.

O workflow `.github/workflows/android-e2e.yml` roda em PRs, pushes na `main` e disparo manual. Ele compila, executa lint e testa em Android APIs 29 e 35. Resultados, XML de telas, screenshots e logs são publicados como artefatos de CI.

A versão 1.3 acrescenta descrições acessíveis para identificar os campos de carga/repetições e seletores nos testes. A assinatura pessoal foi preservada. O certificado do servidor de testes fica apenas no build E2E, fora do APK pessoal.
