# Contexto: Todos

Glossário do bounded context Todos — o painel de To-Do e o ciclo de notificação.

## Termos

- **To-Do (Tarefa)**: unidade de pendência do engenheiro. Tem título, **origem** e **estado**.
- **Origem**: de onde a tarefa veio — `manual` (criada pela UI), `via_jira` (atribuição de
  Code Review via Jira, módulo futuro), `via_transcricao` (action item extraído de
  transcrição de 1-on-1, módulo futuro).
- **Estado**: `pendente` → `snoozed` (até X) → `concluida`.
- **Snoozed**: o lembrete da tarefa está **silenciado até X**; a tarefa continua na fila
  até ser concluída. Adiar não move a tarefa — só para de lembrar por um tempo.
- **Fila de atenção**: painel principal — pendências ordenadas pelo que vence primeiro
  (snoozed volta no horário). Snoozed aparece com opacidade reduzida.
- **Ciclo de notificação**: o intervalo em que o scheduler dispara o lembrete.
  **Resumo único por ciclo**: 1 notificação nativa com o count de pendências
  ("3 pendências: via Jira, manual"), nunca uma notificação por tarefa.
- **Período ativo**: janela de horas em que o ciclo dispara (default 09:00–18:00).
  Fora dela, o scheduler não notifica.
- **Notificável agora**: tarefa pendente, ou snoozed cujo horário já venceu.
  Só notificáveis agora entram no ciclo.
- **Entity imutável**: `Todos::Entities::Todo` é um `Data` — espelho de uma page
  do Database; o backend só lê, o estado é editado no Notion (ADR 0001).
