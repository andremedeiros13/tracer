# Contributing

## Setup

```bash
bin/setup        # gems + banco + seeds + notificação de teste
```

## Antes de compartilhar (com o time)

```bash
bundle exec rubocop        # lint + formatação
bundle exec rspec          # specs
bundle exec brakeman       # security scan (manual, sem hook)
```

RuboCop e RSpec são instalados no projeto (Gemfile) — o `bin/setup` traz tudo.

## Estrutura

- Lógica de domínio: `app/domains/*/use_cases` (interface `.call`) — controllers thin
- Glossário: `CONTEXT.md` (geral) e `app/domains/todos/CONTEXT.md` (contexto Todos)
- Decisões do wayfinding: `.scratch/wayfinder-tracker/` + issues do repo
