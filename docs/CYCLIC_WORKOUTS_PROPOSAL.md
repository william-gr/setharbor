# Proposta: sequência cíclica A/B/C

Pesquisa do código concluída em 2026-10-14. Este documento propõe o comportamento; não altera o aplicativo.

## O que existe hoje

`MainActivity.onCreate` usa o dia da semana apenas como seleção inicial quando não existe `prefs.day`. Depois, `show` persiste o índice selecionado. `finishWorkout` salva a sessão e limpa o rascunho, mas permanece no mesmo treino. Portanto, hoje não há um ciclo que avance ao concluir.

A ficha já é uma lista ordenada, com IDs únicos para seus itens. `WorkoutPlan` não exige nomes de dias da semana: aceita `Treino A`, `Treino B`, etc. Não precisamos renomear o campo JSON `days` nem mudar o formato dos links para representar treinos cíclicos.

## Comportamento recomendado

A ordem da ficha define A → B → C → A (até sete treinos, conforme o limite atual). A data registra quando a sessão ocorreu; não escolhe o treino. Faltar, descansar ou abrir o app em outro dia mantém o próximo da sequência.

Guardar um `nextWorkoutId` separado da seleção de tela. Usar o ID estável do treino, não apenas seu índice, para preservar a posição ao reordenar uma ficha.

| Ação | Efeito na sequência |
| --- | --- |
| Abrir, mudar a data ou reiniciar | Mantém o próximo treino |
| Ver outro treino no seletor | Muda apenas a tela selecionada |
| Marcar séries ou preencher valores | Não avança |
| Cancelar o salvamento, falhar na validação ou na gravação | Não avança; mantém o rascunho |
| Confirmar e salvar o treino esperado | Avança para o sucessor; o último retorna ao primeiro |
| Salvar outro treino como sessão extra | Registra histórico, mas mantém o próximo esperado |
| Escolher explicitamente “Definir como próximo” | Reposiciona a sequência; não cria uma sessão no histórico |

Recomendação para treinos fora da ordem: tratá-los como extras por padrão, para não desorganizar o ciclo ao repetir um treino. A confirmação de salvamento existente deve informar qual será o próximo, sem adicionar outro diálogo. “Definir como próximo” permite pular ou retomar uma posição intencionalmente. Essa decisão ainda pode ser ajustada antes da implementação.

Uma sessão salva com parte das séries, inclusive sem peso/repetições, conta como concluída: o usuário confirmou o encerramento. Não exigir concluir todas as séries nem registrar medições para avançar.

## Interface e persistência

Mostrar `Treino A · Peito e tríceps`, um indicador de próximo treino e um seletor por letras. As letras vêm da posição; os IDs continuam identificando os treinos. Manter os nomes originais das sessões antigas no histórico. Fichas antigas com nomes de dias continuam aceitas; rótulos cíclicos não devem modificar retroativamente seus snapshots.

Ao abrir, sugerir o próximo treino. Se a última seleção tiver rascunho em andamento, retomá-la e mostrar separadamente o próximo da sequência. Rascunhos de outros treinos continuam acessíveis no seletor; nenhuma mudança de cursor os apaga.

Histórico, remoção do rascunho concluído e avanço do cursor devem ocorrer no mesmo `SharedPreferences.Editor.commit()`. Se a gravação falhar, nenhuma dessas alterações deve ser aplicada. Recomenda-se um helper puro `WorkoutSequence` para as regras, coberto pelo gate JVM atual.

## Migração e compatibilidade

- Instalação nova: primeiro treino da ficha.
- Instalação existente sem cursor: usar o sucessor da última sessão pertencente à ficha ativa, identificada pelo ID no snapshot. Na ausência dessa referência, usar a seleção persistida válida; sem nenhuma referência, começar no primeiro. Não inferir a ordem pelo calendário.
- Revisão da mesma ficha: manter o cursor quando o ID continuar existindo; a ordem nova define seu sucessor.
- Ficha nova ou remoção do ID esperado: começar no primeiro e informar o usuário. A proteção existente contra substituir fichas com rascunhos permanece.
- Backup: recomendar v4 com `nextWorkoutId` e seleção de tela, validando IDs contra a ficha. Continuar restaurando v1–v3 com a regra de migração acima. V4 impede que apps antigos restaurem silenciosamente sem preservar a sequência.
- Histórico novo: pode registrar `workoutId` e o rótulo usado na sessão. A leitura dos registros antigos continua usando seu snapshot e índice `day`.
- ChatGPT, importação e links: manter `format`, `schemaVersion` e `days`; orientar o GPT a produzir uma sequência ordenada A/B/C, sem vincular as sessões a dias da semana.

## Verificação necessária para implementar

Testes JVM: ciclo com um, dois e sete treinos; retorno ao primeiro; treinos extras; reposicionamento explícito; IDs desconhecidos; reordenação/remoção de IDs; migração de seleção/histórico antigo. Exigir os mesmos limites de cobertura, sem excluir o helper.

E2E: salvar A e abrir B; concluir o último e voltar a A; reiniciar sem avançar; cancelar/falhar sem avançar; retomar rascunhos; salvar com medições vazias; treino extra; seleção manual e reposicionamento; histórico legado; backup v4 e restauração de v1–v3; fichas antigas importadas e links do ChatGPT. Atualizar os seletores dos testes para letras, preservando as verificações de identidade, séries e dados.

## Próxima implementação

Implementar cursor persistente, seleção A/B/C, avanço atômico ao salvar, migração e backup v4 seguindo esta proposta. Não incluir agenda, notificações ou recomendações de frequência/descanso nesta mudança: o ciclo organiza a ordem escolhida pelo usuário.
