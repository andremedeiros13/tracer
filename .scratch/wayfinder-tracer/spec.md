# Spec: POC do Tracer — To-Do com notificações nativas

> Especificação de implementação, pronta para handoff. Todas as decisões vêm do
> [Wayfinder map: Tracer](https://github.com/andremedeiros13/tracer/issues/1) —
> ver "Decisions so far" para o detalhe de cada decisão, com link para o ticket que a holds.

## 1. O quê

Uma **POC** que valida a funcionalidade principal do Tracer: o **painel de To-Do com
notificações nativas do S.O.**, distribuído localmente para o time de engenharia.

O daemon (processo no host) agenda e dispara **notificações nativas** para quebrar o
estado de hiperfoco; o painel (browser, em `localhost`) mostra a **fila de atenção** —
as pendências ordenadas pelo que vence primeiro.

Fora do escopo desta POC (decisões do mapa já sabem o que receberão, mas nada é
construído aqui):

- **Módulo de tracking** (Jira + commits/PRs + relatório diário)
- **Módulo de parsing de transcrições de 1-on-1**
- **Integração com LLMs/APIs de IA** (diretriz do PRD — vige para todo o projeto)
- Notificações com identidade da aplicação e ações clicáveis (evolução pós-POC)
- iPhone/push (APNs)

## 2. Decisões fundamentais (do mapa)

| Decisão | Resposta | Ticket |
|---|---|---|
| Forma | daemon no host + painel no browser | [#2](https://github.com/andremedeiros13/tracer/issues/2) |
| Notificações | **nativas do S.O.** (requisito rígido) via `notify-send` / `osascript` / PowerShell toast | [#2](https://github.com/andremedeiros13/tracer/issues/2) |
| Plataformas | só desktop — Linux (maioria), macOS, Windows (minoria) | [#2](https://github.com/andremedeiros13/tracer/issues/2) |
| Stack | **Ruby on Rails monolito + SQLite** | [#5](https://github.com/andremedeiros13/tracer/issues/5) |
| Front-end | server-side render (ERB), sem SPA/build step | [#5](https://github.com/andremedeiros13/tracer/issues/5) |
| UI | **fila de atenção + sidebar de navegação**, conteúdo centralizado (max-width 900px) | [#6](https://github.com/andremedeiros13/tracer/issues/6) |
| Ciclo de notificação | **resumo único por ciclo** — 1 notificação nativa com o count de pendências | [#7](https://github.com/andremedeiros13/tracer/issues/7) |
| Estados da tarefa | **Pendente → Snoozed (até X) → Concluída** — "Adiar" silencia o lembrete, não move a tarefa | [#7](https://github.com/andremedeiros13/tracer/issues/7) |
| Distribuição | clone + `bin/setup`/`bin/start`; daemon no login (systemd/LaunchAgent/Tarefa agendada) | [#8](https://github.com/andremedeiros13/tracer/issues/8) |
| Arquitetura | **DDD com bounded contexts** | [#7 addendum](https://github.com/andremedeiros13/tracer/issues/7#issuecomment-5996056358) |
| Linters | RuboCop + rubocop-rails; brakeman manual | [#7 addendum](https://github.com/andremedeiros13/tracer/issues/7#issuecomment-5996056358) |
| Testes | RSpec + factory_bot (instalados no projeto via Gemfile) | [#7 addendum](https://github.com/andremedeiros13/tracer/issues/7#issuecomment-5996056358) |

## 3. Arquitetura

```
tracer/
├── app/
│   ├── domains/
│   │   ├── todos/               ← POC completa
│   │   │   ├── entities/        (Todo: origem, estado Pendente/Snoozed/Concluída)
│   │   │   ├── repositories/    (persistência via ActiveRecord/SQLite)
│   │   │   ├── use_cases/       (NotifyPendingTodos, BuildAttentionQueue,
│   │   │   │                     SnoozeTodo, CompleteTodo, CreateTodo)
│   │   │   └── CONTEXT.md       (glossário do contexto)
│   │   ├── tracking/            ← futuro (Jira/commits/PRs) — vazio, README aponta o que recebe
│   │   │   └── README.md        (pesquisa #4 nomeou o DiscoverReviewer: changelog REST API + customfield)
│   │   └── one_on_ones/         ← futuro (parsing) — vazio, README aponta o que recebe
│   │       └── README.md        (exemplos #3 nomearam o parser: checkboxes `- [ ] [Nome] ...` em `### Próximas etapas`)
│   ├── controllers/             (thin — delegam para use_cases)
│   └── views/                   (fila de atenção + sidebar, ERB)
├── lib/                         (notificador nativo: notify-send / osascript / toast)
├── bin/                         (setup, start)
└── CONTEXT.md                   (glossário geral)
```

### 3.1. Contexto Todos (a POC)

- **Entities**: `Todo` (título, origem `manual|via_jira|via_transcricao`, estado
  `pendente|snoozed|concluida`, snoozed_ate, timestamps)
- **Repositories**: persistência via ActiveRecord (SQLite), interface de repositório
  para os use-cases
- **Use cases** (`.call` como interface):
  - `NotifyPendingTodos` — o ciclo do daemon: agrega pendências (não-snoozed) e
    dispara 1 notificação nativa com o resumo ("3 pendências: code review, 1-on-1, manual")
  - `BuildAttentionQueue` — a fila de atenção: pendências ordenadas pelo que vence
    primeiro (snoozed volta no horário)
  - `SnoozeTodo` — silencia o lembrete da tarefa até X (a tarefa continua na fila)
  - `CompleteTodo` — marca como concluída
  - `CreateTodo` — criação manual pela UI
- **Scheduler**: thread dentro do `rails server` (inicializador), disparando
  `NotifyPendingTodos` no intervalo configurado pelo usuário; respeita o período ativo

### 3.2. Notificador nativo (`lib/`)

- Shell-out para os comandos nativos de cada S.O.: `notify-send` (Linux),
  `osascript -e 'display notification ...'` (macOS), PowerShell toast (Windows)
- **Sem gem/biblioteca de notificação** — zero dependência extra
- Na primeira execução/`bin/setup`, dispara uma **notificação de teste** para o
  usuário conceder permissão na hora (macOS/Windows)

### 3.3. Painel (views, ERB)

- **Fila de atenção** (validada no protótipo, branch `prototype/ui-todo-painel`):
  - Sidebar: Tracer (marca) → To-Do (ativo) / Entregas do dia / 1-on-1 / Configurações
    (módulos futuros como navegação visível)
  - Alertas ordenados por vencimento, ações por item (Concluir / Adiar 1h), badges
    de origem (via Jira / manual / transcrição)
  - Config de lembretes embutida (frequência + período ativo)
  - Conteúdo centralizado (`max-width: 900px; margin: 0 auto`) no espaço restante
    à direita da sidebar
- **Seed no setup**: 2-3 tarefas de exemplo pré-criadas nas **três origens** —
  exercita a UI das fontes sem uma linha de integração

## 4. Distribuição

- **Clone + `bin/setup`** (gems + SQLite + seed) e **`bin/start`** (sobe o daemon)
- Pré-requisitos no README: Ruby 4.x (macOS/Windows: runtime instalado uma vez)
- **README: requisito explícito — claro, bonito e fácil de entender** para que
  qualquer pessoa consiga instalar sem ajuda (prova o critério de sucesso #1)
- **Daemon no login**: systemd user unit (Linux) / LaunchAgent (macOS) / Tarefa
  agendada (Windows) — com restart automático; arquivos fornecidos no repo
- **Permissões**: notificação de teste na primeira execução

## 5. Qualidade

- **RuboCop + rubocop-rails** (config mínima no repo) — lint + formatação
- **brakeman** — comando manual antes de compartilhar com o time (sem hook)
- **RSpec + factory_bot** — testes dos use-cases (scheduler, notificador, agregador)
  e do modelo de estados; cobertura nos caminhos que evoluem
- **CONTEXT.md** (glossário: To-Do, Fila de atenção, Origem, Snoozed, Resumo único) —
  o código fala a língua do domínio das decisões do mapa
- **.editorconfig + .gitignore** completos desde o primeiro commit
- **CONTRIBUTING.md mínimo** (como rodar lint + testes)

## 6. Critérios de sucesso da POC

1. **Instalação**: 2+ pessoas do time (além do builder) instalam e rodam a POC
   seguindo só o README, sem ajuda — em ≤30 min
2. **Notificações**: o alerta nativo aparece em Linux, macOS e Windows (pelo menos
   1 pessoa em cada S.O. que testar)
3. **Efetividade**: depois de 1 semana usando, as pessoas relatam que as
   notificações as fizeram agir em pendências esquecidas

O rollout (PRD §5) só acontece após os 3 critérios provados; os módulos de tracking
e parsing seguem após a POC, como novo esforço.
