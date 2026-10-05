# Spec: Módulo de Tracking — rastreio de entregas diárias

> Especificação de implementação. Decisões do
> [Wayfinder map: Tracer — módulos de tracking e 1-on-1](https://github.com/andremedeiros13/tracer/issues/9)
> (formato #11, protótipo #12, pesquisa #4 do mapa anterior).

## 1. O quê

Completar o bounded context **Tracking** (hoje fronteira nomeada em
`app/domains/tracking/`): coletar as entregas do usuário no dia — cards movimentados
no Jira, commits e Pull Requests (GitHub) — consolidar em um **snapshot diário
persistido no SQLite**, e exibir no painel como a página **"Entregas do dia"**
(timeline cronológica com eventos clicáveis, navegação por dia).

## 2. Decisões fundamentais (do mapa)

| Decisão | Resposta | Ticket |
|---|---|---|
| Escopo | **tudo do PRD** — cards movimentados (Jira) + PRs abertos/revisados + commits próprios | [#11](https://github.com/andremedeiros13/tracer/issues/11) |
| Geração | **snapshot persistido** — o scheduler consolida o dia e grava no SQLite; a página lê o snapshot | [#11](https://github.com/andremedeiros13/tracer/issues/11) |
| Commits | **a org inteira** (`ResultadosDigitais` — GitHub, verificado ao vivo) | [#11](https://github.com/andremedeiros13/tracer/issues/11) |
| Histórico | **navegável por dia** no painel (dia anterior/seguinte, lendo snapshots) | [#11](https://github.com/andremedeiros13/tracer/issues/11) |
| UI | **variante A — timeline cronológica** com eventos clicáveis (URL real persistido) | [#12](https://github.com/andremedeiros13/tracer/issues/12) |

## 3. Arquitetura (DDD no contexto tracking)

```
app/domains/tracking/
├── entities/
│   ├── delivery.rb        (Delivery: data, origem jira|commit|pull_request,
│   │                       título, descrição, estado, url, hora)
│   └── daily_snapshot.rb  (DailySnapshot: data, consolidado_at)
├── repositories/
│   ├── delivery_repository.rb
│   └── daily_snapshot_repository.rb
├── use_cases/
│   ├── build_daily_snapshot.rb     (consolida o dia: coleta + persiste)
│   ├── collect_moved_issues.rb     (Jira changelog)
│   ├── collect_pull_requests.rb    (GitHub: abertos/revisados)
│   ├── collect_commits.rb          (GitHub: commits do dia)
│   └── discover_reviewer.rb        (customfield do Jira — fase 2)
└── CONTEXT.md
```

- **Entity `Delivery`**: `data` (date), `origem` (`jira | commit | pull_request`),
  `titulo` (ex: "Abriu PR #142 — auth-service"), `descricao`, `estado`
  (para PRs: aberto/changes requested/merged), `url` (link real, clicável),
  `hora` (timestamp do evento), referência ao snapshot
- **Entity `DailySnapshot`**: um por dia — o relatório "que não se perde"
- **Use cases** (`.call`):
  - `BuildDailySnapshot` — o ciclo: coleta os 3 tipos, persiste as entregas
    do dia no snapshot (idempotente por dia)
  - `CollectMovedIssues` — Jira: changelog do dia filtrado por autor
  - `CollectPullRequests` — GitHub: `is:pr author:@me` + `is:pr reviewed-by:@me`
  - `CollectCommits` — GitHub: `author:@me` + data, na org inteira
  - `DiscoverReviewer` — fase 2 (customfield Reviewer, só depois das credenciais)

## 4. Coleta (fatos verificados na pesquisa)

### 4.1. Jira Cloud (rdstation.atlassian.net)

- Cards movimentados: `GET /rest/api/3/issue/{issueIdOrKey}/changelog` (paginado,
  oldest-first; filtrar `author.accountId` + dia; cada entrada tem `items[]` com
  `fieldId`, `fromString`/`toString`)
- Issues candidatos: JQL em campos normais (`updated >= -1d`) — **JQL history
  (CHANGED/WAS) não funciona em custom fields** (limitação documentada)
- Customfield Reviewer: `GET /rest/api/3/field/search?type=custom&query=Reviewer`
  (fase 2 — descobrir o id, rastrear via changelog filtrando `items[].fieldId`)
- Auth: HTTP Basic `email:token` — variáveis de ambiente `JIRA_EMAIL` +
  `JIRA_API_TOKEN` (dotenv-rails já no Gemfile; **token nunca em conversa/ticket/commit**)
- URL do card: `https://rdstation.atlassian.net/browse/{key}`

### 4.2. GitHub (gh CLI / API)

- PRs abertos: `gh search prs "is:pr author:@me created:>=<dia>"` (org incluída)
- PRs revisados: `is:pr reviewed-by:@me updated:>=<dia>` — detalhes de estado via
  `GET /repos/{owner}/{repo}/pulls/{n}/reviews` (filtro client-side por `user.login`)
- Commits: `gh search commits "author:@me committer-date:>=<dia>"` — só a branch
  default; na org inteira
- URL do commit: `github.com/{org}/{repo}/commit/{sha}`; do PR: `github.com/{org}/{repo}/pull/{n}`

## 5. Scheduler

- O ciclo existente (`config/initializers/scheduler.rb`) ganha um segundo passo:
  `Tracking::UseCases::BuildDailySnapshot.new.call` — consolida o dia a cada ciclo
  (idempotente por dia: re-coletar substitui o snapshot do dia)
- A coleta roda no mesmo período ativo das notificações (ou sempre — decisão simples:
  sempre, pois o snapshot não notifica nada)

## 6. Painel

- **Página "Entregas do dia"** (substitui a página "em breve"):
  - Timeline cronológica (variante A validada): eventos ordenados por hora,
    badge de fonte (Jira / commit / PR), **eventos clicáveis** (url real)
  - **Navegação por dia**: ← dia anterior / seguinte →, lendo snapshots do SQLite
  - Resumo no topo ("Snapshot consolidado pelo daemon · N entregas")
  - Mesma sidebar validada; conteúdo centralizado (max-width 900px)
- Routes: `GET /entregas` (hoje) + `GET /entregas?dia=2026-10-04` (histórico)

## 7. Qualidade

- **RuboCop + rubocop-rails** (config existente)
- **RSpec + factory_bot**: specs dos use cases de coleta (com APIs stubadas —
  WebMock ou doubles), do snapshot (idempotência por dia), e request specs da página
- **Sem credenciais em teste**: os specs stubam as APIs; a coleta real só roda
  com o `.env` configurado
- Caso de teste real: os commits em `ResultadosDigitais/totvs-pay` (verificado ao vivo)

## 8. Critérios de aceite

1. `bin/setup` + `bin/start` com `.env` configurado → o snapshot do dia é
   consolidado e a página "Entregas do dia" mostra a timeline com as entregas reais
2. Eventos clicáveis abrem card/commit/PR nos URLs reais
3. Navegação por dia mostra os snapshots anteriores
4. Sem `.env` → a página mostra estado vazio com aviso (não quebra)
5. Specs verdes + RuboCop limpo + brakeman sem warnings críticos
