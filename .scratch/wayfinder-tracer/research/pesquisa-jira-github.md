# Pesquisa: acesso ao Jira Cloud e ao GitHub para rastreio futuro

Ticket de origem: #4 on andremedeiros13/tracer ("Pesquisar acesso ao Jira Cloud e ao GitHub para rastreio futuro").
Data: 2026-10-05. Escopo: apenas documentação/pesquisa — nenhum código construído.

Todas as afirmações abaixo foram verificadas contra fontes primárias (documentação oficial Atlassian, GitHub Docs, Figma, ThemeForest, e testes ao vivo com o `gh` CLI). Cada seção cita a fonte.

---

## 1. Jira Cloud REST API

### 1.1 Coletar issues movidas por um usuário no dia — changelog API

Fonte: [REST API v3 — Issue changelog](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-changelog/) (verificado no HTML/OpenAPI da página em 2026-10-05).

**Endpoint paginado (recomendado):**

```
GET /rest/api/3/issue/{issueIdOrKey}/changelog?startAt=0&maxResults=100
```

- Documentação: "Returns a paginated list of all changelogs for an issue sorted by date, starting from the oldest."
- Permissão requerida: *Browse projects* no projeto do issue (e permissão de issue-level security, se configurada).
- Parâmetros de paginação confirmados no schema: `startAt` (offset da página) e `maxResults` (default **100**). A resposta inclui `startAt`, `maxResults`, `total`, `isLast` (flag de fim) e `nextPage` (URL da próxima página) — paginação por `isLast`/`nextPage`, não por `startAt` manual apenas.
- Resposta 404 quando o issue não existe ou o usuário não tem permissão de visualização.

**Estrutura de um item de changelog** (confirmada no exemplo OpenAPI):

```json
{
  "values": [
    {
      "author": { "accountId": "5b10a2844c20165700ede21g", "displayName": "Mia Krystof", "emailAddress": "mia@example.com", "timeZone": "Australia/Sydney" },
      "created": "1970-01-18T06:27:50.429+0000",
      "id": "10001",
      "items": [
        { "field": "fields", "fieldtype": "jira", "fieldId": "fieldId",
          "from": null, "fromString": "",
          "to": null, "toString": "label-1" }
      ]
    }
  ]
}
```

- Cada entrada `items[]` tem `field`, `fieldtype`, `fieldId`, `from`/`to` (IDs dos valores antigo/novo) e `fromString`/`toString` (valores legíveis). É aqui que se identifica **quem** moveu o card (`author.accountId` + `created`) e **o que** mudou (`field: "status"`, `toString: "In Progress"`, etc.).
- Para "cards movidos por um usuário no dia": buscar issues do dia via JQL (seção 1.2), depois para cada issue chamar o changelog e filtrar entradas onde `author.accountId == <engenheiro>` e `created` cai no dia alvo.

**Endpoint alternativo por lista de IDs:**

```
POST /rest/api/3/issue/{issueIdOrKey}/changelog/list
```
- Body: `{"changelogIds":[10001,10002]}`. Retorna `histories[]` no formato legado (com `histories`, `maxResults`, `startAt`, `total`). Útil para resolver changelogs específicos sem paginar tudo.

**Expand `changelog` no GET do issue** (fonte: [REST API v3 — Get issue](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/), texto do parâmetro `expand` verificado):

> "`changelog` Returns a list of recent updates to an issue, sorted by date, starting from the most recent. **This returns a maximum of 40 changelogs.** If you require more, please refer to [the paginated changelog endpoint]."

- `expand` é uma lista/comma-delimited: `expand=changelog,names,renderedFields`.
- **Implicação prática para o tracer:** `expand=changelog` no GET do issue só traz os 40 changelogs mais recentes — suficiente para rastreio diário, mas insuficiente para histórico longo. Para varredura completa usar `GET /issue/{idOrKey}/changelog` paginado.

### 1.2 JQL com funções de histórico — e a limitação crítica

Fonte: [JQL operators — Jira Cloud](https://support.atlassian.com/jira-software-cloud/docs/advanced-search-reference-jql-operators/) (texto extraído da página em 2026-10-05) e [REST API v3 — Search endpoints](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/).

**Operadores de histórico confirmados (sintaxe exata da documentação):**

- `assignee CHANGED` — encontra issues cujo assignee mudou.
- `status CHANGED FROM "In Progress" TO "Open"` — mudança de valor antigo para novo.
- `priority CHANGED BY freddo BEFORE endOfWeek() AFTER startOfWeek()` — restringe por usuário e janela de tempo.
- Predicados opcionais do operador `CHANGED`: `AFTER "date"`, `BEFORE "date"`, `BY "username"`, `DURING ("date1","date2")`, `ON "date"`, `FROM "oldvalue" TO "newvalue"`.
- Operadores históricos de valor: `WAS`, `WAS IN`, `WAS NOT IN`, `WAS NOT` (ex.: `status WAS "In Progress"`, `status WAS NOT "In Progress" BEFORE "2011/02/02"`).
- Não existe uma função JQL chamada `changed()` ou `changedBy()` — essas formas são o operador `CHANGED` com os predicados `BY`/`FROM`/`TO`/`AFTER`/`BEFORE`/`DURING`/`ON` acima.

**LIMITAÇÃO CRÍTICA (texto literal da documentação):**

> "This operator can be used with the **Assignee, Fix Version, Priority, Reporter, Resolution, and Status fields only**." (aplica-se tanto ao `WAS` quanto ao `CHANGED`)

- Ou seja: **JQL de histórico NÃO funciona com campos customizados** como um campo "Reviewer". Para rastrear mudanças em um customfield, o caminho é o **changelog REST API** (seção 1.1) — buscar os issues por outro critério (ex.: `project = X AND updated >= -1d`) e filtrar as entradas do changelog por `fieldId == customfield_XXXXX`.
- Nota adicional da documentação: se um work item tem mais de 10.000 mudanças, queries JQL com `WAS` só pesquisam as mudanças mais recentes.

**Endpoint de busca por JQL (v3):**

```
GET /rest/api/3/search/jql?jql=<jql>&nextPageToken=<token>&maxResults=50&fields=...
```

- Documentação: "Searches for issues using JQL. Recent updates might not be immediately visible in the returned search results." Parâmetros confirmados no schema: `jql`, `nextPageToken`, `maxResults`, `fields`, `expand`, `properties`, `fieldsByKeys`, `failFast`, `reconcileIssues`, `includeArchivedProjects`.
- Endpoint legado `GET /rest/api/3/search` também existe; e `POST /rest/api/3/search/approximate-count` para contagem.
- Exemplo de JQL diário para o tracer: `project = ENG AND updated >= -1d` ou `assignee = <accountId> AND updated >= -1d` (o `updated` é campo normal, sem restrição de histórico).

### 1.3 Ler um custom field como "Reviewer" — descoberta do customfield_*

Fonte: [REST API v3 — Issue fields](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/) (verificado no HTML/OpenAPI da página em 2026-10-05).

**Endpoint paginado de descoberta:**

```
GET /rest/api/3/field/search?startAt=0&maxResults=50&type=custom&query=Reviewer
```

- Descrição literal: "Returns a paginated list of fields for Classic Jira projects. The list can include: all fields; specific fields, by defining `id`; fields that contain a string in the field name or description, by defining `query`... Use `type` must be set to `custom` to show custom fields only."
- Permissão requerida: permissão de acessar Jira.
- Parâmetros confirmados no schema: `startAt`, `maxResults`, `type`, `id`, `query`, `orderBy`, `expand`, `projectIds`.
- Exemplo de resposta (do OpenAPI da própria página):

```json
{
  "isLast": false, "maxResults": 50, "startAt": 0, "total": 2,
  "values": [
    {
      "id": "customfield_10000",
      "name": "Approvers",
      "key": "customfield_10000",
      "schema": { "custom": "com.atlassian.jira.plugin.system.customfieldtypes:multiuserpicker",
                  "customId": 10000, "items": "user", "type": "array" },
      "description": "Contains users needed for approval...",
      "searcherKey": "com.atlassian.jira.plugin.system.customfieldtypes:userpickergroupsearcher"
    }
  ]
}
```

- O `id` de cada resultado é o `customfield_XXXXX` usado em JQL, payload de create/edit e no changelog (`fieldId`).
- `schema.type` + `schema.items` revelam o tipo do campo (para "Reviewer" tipicamente `array` de `user` — um multi-user picker).

**Endpoint alternativo (não paginado, mais amplo):**

```
GET /rest/api/3/field
```
- "Returns system and custom issue fields according to the following rules... For all other fields, this operation only returns the fields that the user has permission to view." Sem os filtros de busca, mas útil para listar tudo de uma vez.

**Como ler o valor do campo em um issue:** `GET /rest/api/3/issue/{issueIdOrKey}?fields=customfield_10000` (ou `fieldsByKeys=true&fields=Reviewer` — o parâmetro `fieldsByKeys` do endpoint de busca aceita chaves por nome).

### 1.4 Como funciona o token de API por-engenheiro

Fonte: [Manage API tokens for your Atlassian account](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/) (texto extraído da página em 2026-10-05).

**Criação do token:**

1. Logar em `https://id.atlassian.com/manage-profile/security/api-tokens`.
2. "Create API token" (sem scopes) ou "Create API token with scopes".
3. Nome do token, data de expiração (**1 a 365 dias** para tokens com scopes; tokens clássicos sem scopes expiram em 1 ano — os existentes expirarão entre 14 de março e 12 de maio de 2026).
4. Para tokens com scopes: selecionar o app (Jira/Confluence) e os scopes; o token chama a API via gateway: `https://api.atlassian.com/ex/jira/{cloudId}` (ou `/ex/confluence/{cloudId}`).
5. O token é mostrado **uma única vez** — "You can't recover the API token after you're done with this step."

**Formato de autenticação (HTTP Basic com email + token):**

```bash
# Token clássico (sem scopes) — base URL do site
curl -v https://mysite.atlassian.net --user me@example.com:my-api-token

# Token com scopes — via gateway com cloudId
curl -v https://api.atlassian.com/ex/jira/{cloudId} --user me@example.com:my-api-token
```

- `me@example.com` é o email da conta Atlassian que criou o token; o token substitui a senha no Basic auth.
- Tokens têm **comprimento variável** (não fixo) por segurança — o código do tracer não deve assumir tamanho fixo.
- Para scripts: "If you use two-step verification to authenticate, your script needs to use a REST API token to authenticate" — ou seja, o token é o único caminho para automação quando a conta tem 2FA.
- Scopes OAuth2 dos endpoints de leitura usados aqui (do OpenAPI dos endpoints): `read:jira-work` (scope atual) para changelog e busca.
- Verificação de identidade: ao criar/gerenciar tokens com login por senha ou terceiro, a Atlassian envia um one-time passcode por email; com SSO ou service account não é pedido.

**Decisão que espera este fato:** para o tracer, cada engenheiro cria seu próprio token (clássico, sem scopes, expiração de 1 ano) em id.atlassian.com e o tracer autentica com Basic `email:token` contra `https://<site>.atlassian.net`. A alternativa (token com scopes + gateway `api.atlassian.com/ex/jira/{cloudId}`) é mais restritiva e requer conhecer o `cloudId` — recomendada quando houver política de escopos.

---

## 2. GitHub API (gh CLI)

### 2.1 PRs abertos por um usuário

Fontes: [Searching issues and pull requests](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests) e testes ao vivo com `gh search prs` (2026-10-05).

**Qualificadores de busca confirmados (sintaxe exata da documentação):**

- `is:pr author:USERNAME` — "finds items created by @gjtorikian" (ex.: `cool author:gjtorikian`).
- `is:pr reviewed-by:USERNAME` — "matches pull requests reviewed by a particular person" (ex.: `type:pr reviewed-by:gjtorikian`).
- `review-requested:USERNAME` — PRs onde a pessoa foi solicitada para review. Nota da documentação: "Requested reviewers are no longer listed in the search results after they review a pull request."
- `review-involves:USERNAME` — combina reviews feitos e solicitados.
- `review:required` / `review:none` / `review:approved` / `review:changes_requested` — estado de review do PR.
- `mentions:USERNAME` — issues/PRs que mencionam o usuário.
- Datas (ISO8601, com operadores de range): `created:YYYY-MM-DD`, `updated:YYYY-MM-DD`, `closed:YYYY-MM-DD`, `merged:YYYY-MM-DD` — ex.: `merged:>=2014-05-01`, `closed:<2012-10-01`, e com horário `THH:MM:SS+00:00`.
- Extras: `is:merged`, `is:unmerged`, `draft:true/false`, `head:BRANCH`, `base:BRANCH`, `status:pending|success|failure`, SHA de commit (mínimo 7 caracteres, combinável com `is:merged`).

**Exemplo diário para o tracer:**

```bash
gh search prs "is:pr author:@me created:>=2026-10-04" --json repository,title,url,createdAt,state
gh search prs "is:pr reviewed-by:@me updated:>=2026-10-04" --json repository,title,url,state
```

Observação de teste ao vivo: a busca `is:pr reviewed-by:defunkt` retornou `[]` (vazio) mas executou sem erro — o qualificador é válido; o vazio é resultado, não falha.

**Exemplo em org:** `org:ORGNAME` restringe aos repositórios da org (ex.: `is:pr author:USERNAME org:andremedeiros13 merged:>=2026-10-04`).

### 2.2 Reviews de um PR — endpoints REST

Fonte: [REST API — Pull request reviews](https://docs.github.com/en/rest/pulls/reviews?apiVersion=2022-11-28) (verificado em 2026-10-05).

```
GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews
GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/comments
```

- "The list of reviews returns in chronological order." Paginação: `per_page` (default 30, max 100) e `page`.
- Campos de resposta confirmados: `id`, `node_id`, `user` (Simple User com `login`), `body`, `state`, `html_url`, `pull_request_url`, `submitted_at`, `commit_id`, `author_association`.
- Valores de `state` observados na documentação/código de exemplo: `APPROVED`, `CHANGES_REQUESTED`, `PENDING`, `DISMISSED`.
- **Não existe endpoint "reviews por usuário"** — reviews são listados por PR e filtrados client-side pelo campo `user`. Por isso o fluxo do tracer é: busca de PRs por `reviewed-by:@me` (seção 2.1) para achar os PRs, e opcionalmente os endpoints acima para detalhes (estado, comentários, commit_id).
- Permissões (fine-grained PAT): **"Pull requests" repository permissions (read)** — confirmado no texto do endpoint "List reviews for a pull request". Funciona sem autenticação apenas em recursos públicos.

### 2.3 Commits por um usuário em uma org

Fonte: [Searching commits](https://docs.github.com/en/search-github/searching-on-github/searching-commits) e [REST API — Pulls](https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28) (verificados em 2026-10-05).

**Qualificadores de busca de commits confirmados (sintaxe exata):**

- `author:USERNAME` — "matches commits authored by @defunkt".
- `committer:USERNAME` — "matches commits committed by @defunkt".
- `author-name:NAME` / `committer-name:NAME` — match no nome (ex.: `author-name:wanstrath`).
- `author-email:EMAIL` / `committer-email:EMAIL` — match no email completo.
- `author-date:YYYY-MM-DD` / `committer-date:YYYY-MM-DD` — com operadores (ex.: `author-date:<2016-01-01`, `committer-date:>2016-01-01`).
- Escopo: `user:USERNAME` (todos os repos do usuário), `org:ORGNAME`, `repo:OWNER/REPO`.
- `hash:HASH` — match por SHA-1; `parent:HASH`, `merge:true/false`, `is:public/is:private`.
- Nota da documentação: **apenas a branch default é pesquisada**; termos multi-word em aspas.

**Exemplo diário para o tracer:** `author:USERNAME org:andremedeiros13 committer-date:>=2026-10-04`.

**Commits de um PR via REST:** `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits` — "Lists a maximum of 250 commits for a pull request. To receive a complete commit list for pull requests with more than 250 commits, use the List commits endpoint." Permissões: **"Pull requests" repository permissions (read)** (confirmado no texto do endpoint).

### 2.4 Auth: scopes de PAT e `gh auth`

Fontes: [REST API — Getting started](https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28), páginas de endpoints acima, e `gh auth status` ao vivo (2026-10-05).

**Classic PAT (escopos confirmados):**

- Endpoints de leitura de PRs/commits/search funcionam com o escopo `repo` (acesso a repositórios privados) — recursos públicos funcionam sem autenticação.
- Exemplo de header na documentação: `X-Oauth-Scopes: gist, read:org, repo, workflow` (ilustrativo, não requisito). Para ler repos de uma org privada via PAT clássico, `repo` + `read:org` é o par necessário.
- `gh` CLI ao vivo nesta máquina: `gh auth status` mostra token `gho_...` com scopes `'gist', 'read:org', 'repo', 'workflow'` — suficiente para todo o rastreio do tracer (busca de PRs, reviews, commits em `andremedeiros13`).

**Fine-grained PAT (permissões confirmadas por endpoint):**

- `GET /repos/{owner}/{repo}/pulls` (List pull requests): **"Pull requests" repository permissions (read)**.
- `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews`: **"Pull requests" repository permissions (read)**.
- `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits`: **"Pull requests" repository permissions (read)**.
- "Pull requests" read cobre Metadata implicitamente para os endpoints listados; funciona sem autenticação apenas em recursos públicos.
- Para commits por busca em org: permissões de leitura nos repos da org (fine-grained PAT precisa de acesso a cada repo, ou org-wide via GitHub App).

**Decisão que espera este fato:** para o tracer com `gh` CLI já autenticado (scopes `repo`, `read:org`), nenhum setup adicional é necessário. Para automação server-side sem `gh`, um PAT clássico com `repo` + `read:org` ou um fine-grained PAT com "Pull requests: read" nos repos alvo cobre todos os endpoints usados.

---

## 3. UI reference templates (referências reais para o dashboard)

PRD exige documentar fontes reais. Todas as URLs abaixo foram **verificadas ao vivo** (Figma Community via busca real da comunidade; ThemeForest via páginas de item; GitHub via API). Nenhuma URL abaixo retornou 404 — IDs que apareceram em resultados de busca sintetizada (IA) e que retornaram 404 ao vivo foram descartados.

### 3.1 Figma Community (gratuitos, verificados)

1. **Task Management Dashboard – Pickolab Studio** — por Pickolab Studio, **Free**, 656 duplicações, 24.1k visualizações.
   https://www.figma.com/community/file/1141955831276958587/task-management-dashboard-pickolab-studio
2. **Tasky - Task and Time Management Dashboard** — por Manjay Gupta, **Free**, 208 duplicações, 11.4k visualizações.
   https://www.figma.com/community/file/1028730836034343781/tasky-task-and-time-management-dashboard
3. **Task Flow - Project Management Dashboard UI** — por Ayman Eid, **Free**, 351 duplicações, 13.9k visualizações.
   https://www.figma.com/community/file/1224268866120711793/task-flow-project-management-dashboard-ui
4. (Alternativa) **Plan It - Free Task & Project Management Dashboard UI Kit** — por KRISTE RI, **Free**, 113 duplicações.
   https://www.figma.com/community/file/1291115639727516852/plan-it-free-task-project-management-dashboard-ui-kit

### 3.2 ThemeForest / Envato (comerciais, verificados)

1. **Taskify - Task Management NextJs Admin Dashboard Template** — por dexignlabs (Elite Author), **$14** (Regular) / $349 (Extended), 6 vendas, atualizado 6 Jan 2026 (v1.0). Next.js 16, React 19, TypeScript, Tailwind CSS. Features: analytics/stats cards, task creation/assignment/deadline tracking, role-based access, dark/light mode, 177+ reusable components.
   https://themeforest.net/item/taskify-task-management-nextjs-admin-dashboard-template/61127593
2. **Mytask - Hr, Project Management Admin Template** — por pixelwibes, **$29** (Regular) / $399 (Extended), 229 vendas. Bootstrap 5x, SASS, HTML5, CSS3, jQuery. Features: kanban/task boards, calendar e chat, sidebar/mini-sidebar/RTL, light & dark versions.
   https://themeforest.net/item/mytask-hr-project-management-admin-template/31974551
3. **Taskora - Project Management Tailwind CSS Next JS Admin Dashboard Template** — por UIAXIS, **$39** (Regular) / $600 (Extended), 32 vendas. Next.js 15.3.2 + Tailwind CSS. Features: drag-and-drop tasks (react-dnd), Recharts, calendar, react-hook-form + Zod, CMDK command menus, dark/light via next-themes.
   https://themeforest.net/item/taskora-project-management-tailwind-css-next-js-admin-dashboard-template/58164858

### 3.3 Open-source GitHub repos (verificados via API, 2026-10-05)

1. **Kiranism/next-shadcn-dashboard-starter** — MIT, 7.1k stars. "Free, open source (MIT) admin dashboard starter built with Next.js 16, shadcn/ui on Base UI primitives, TypeScript, and Tailwind CSS v4."
   https://github.com/Kiranism/next-shadcn-dashboard-starter
   **Lição de layout:** o README contrasta-se com templates estáticos ("Most dashboard templates are static demo boilerplates: screens that look finished but need rebuilding the moment you wire in real data") — o valor do layout está em componentes vivos ligados a dados reais (tabelas, formulários, auth, billing já prontos), não em screenshots. Demo: https://dub.sh/shadcn-dashboard
2. **arhamkhnz/next-shadcn-admin-dashboard** — MIT, 3.1k stars, homepage https://studio-admin.arhamkhnz.com. "Modern Admin Dashboard Template built with Shadcn UI and Next.js 16."
   https://github.com/arhamkhnz/next-shadcn-admin-dashboard
   **Lição de layout:** dashboard admin moderno com sidebar + área de conteúdo — referência direta para a estrutura do tracer (coluna lateral de navegação, listas lado a lado na área principal).
3. **Phantas0s/devdash** — Apache, 1.6k stars, Go. "Highly Configurable Terminal Dashboard for Developers and Creators" (TUI, não web).
   https://github.com/Phantas0s/devdash
   **Lição de layout:** filosofia de widgets configuráveis — "Choose the widgets you want. Place your widgets where you want. Choose the data you want to display, the colors you want to use" — aplica-se ao tracer como: cada painel (Jira movido, PRs abertos, reviews, commits) é um widget independente configurável, sem acoplamento entre eles. Repos semelhantes com layout de internal tools web, caso precise: appsmithorg/appsmith (Apache-2.0, 41k stars, plataforma de admin panels/internal tools) e refinedev/refine (MIT, 35k stars, framework React para internal tools).

### 3.4 Lições de layout consolidadas para o tracer

- **Listas lado a lado sem clutter** (padrão dos três Templates de dashboard + shadcn starter): colunas/colunas de painel independentes, cada uma com contagem no header e lista rolável — não grid denso de cards pequenos.
- **Sidebar + área de conteúdo** (arhamkhnz, Mytask, Taskify): navegação por fonte de dados (Jira / GitHub / Engenheiro) na sidebar, listas na área principal.
- **Stats row no topo** (Taskify, Tasky): contagens do dia (cards movidos, PRs abertos, reviews feitos) como linha de tiles acima das listas.
- **Dados reais primeiro** (Kiranism/next-shadcn-dashboard-starter): o layout deve ser desenhado em cima dos dados que o tracer coleta (estrutura das seções 1 e 2), não em cima de um mock estático.

---

## 4. Resumo dos fatos que uma decisão espera

| Decisão | Fato verificado |
|---|---|
| Como rastrear mudanças em um custom field "Reviewer" | **JQL `CHANGED`/`WAS` NÃO funciona com custom fields** (só Assignee, Fix Version, Priority, Reporter, Resolution, Status — texto literal da doc). O caminho é o changelog REST API: `GET /rest/api/3/issue/{idOrKey}/changelog` (paginado, `maxResults` default 100, `isLast`/`nextPage`) e filtrar `items[].fieldId == customfield_XXXXX`. |
| Descoberta do customfield_* | `GET /rest/api/3/field/search?type=custom&query=Reviewer` (params: `startAt`, `maxResults`, `type`, `id`, `query`, `orderBy`, `expand`, `projectIds`); alternativa `GET /rest/api/3/field`. |
| Auth Jira por-engenheiro | Token em `https://id.atlassian.com/manage-profile/security/api-tokens`; Basic auth `email:token` contra `https://<site>.atlassian.net`; expiração 1–365 dias (com scopes) ou 1 ano (clássico); token mostrado uma única vez. |
| Auth GitHub | `gh` CLI nesta máquina já tem scopes `repo`, `read:org`, `workflow`, `gist` — suficiente. PAT clássico `repo` + `read:org` ou fine-grained PAT com **"Pull requests" repository permissions (read)** cobre todos os endpoints de PR/review/commit usados. |
| Busca de PRs por usuário | `is:pr author:USERNAME`, `is:pr reviewed-by:USERNAME`, `review-requested:USERNAME`, `review-involves:USERNAME`, datas ISO8601 (`created:`, `merged:>=`). Não existe endpoint "reviews por usuário" — filtrar client-side por `user.login` após `GET /repos/{owner}/{repo}/pulls/{n}/reviews`. |
| Busca de commits por usuário em org | `author:USERNAME org:ORGNAME committer-date:>=YYYY-MM-DD`; apenas a branch default é pesquisada. `GET /repos/{owner}/{repo}/pulls/{n}/commits` lista no máximo 250 commits por PR. |
| Expand changelog | `expand=changelog` no GET do issue traz no máximo **40 changelogs**; para histórico completo usar o endpoint paginado. |
| Templates de UI (origens verificadas) | Figma Community (3 gratuitos, links com autor + contagem), ThemeForest (3 comerciais, links com preço + vendas), GitHub open-source (3 repos, MIT/Apache, com lições de layout). Nenhuma URL acima retornou 404. |

---

## Fontes

- [REST API v3 — Issue changelog (Atlassian)](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-changelog/)
- [REST API v3 — Issue fields (Atlassian)](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/)
- [REST API v3 — Issue search (Atlassian)](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/)
- [REST API v3 — Issues (Atlassian)](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/)
- [JQL operators (Atlassian)](https://support.atlassian.com/jira-software-cloud/docs/advanced-search-reference-jql-operators/)
- [Manage API tokens for your Atlassian account (Atlassian)](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)
- [Searching issues and pull requests (GitHub Docs)](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests)
- [Searching commits (GitHub Docs)](https://docs.github.com/en/search-github/searching-on-github/searching-commits)
- [REST API — Pull request reviews (GitHub Docs)](https://docs.github.com/en/rest/pulls/reviews?apiVersion=2022-11-28)
- [REST API — Pulls (GitHub Docs)](https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28)
- [REST API — Getting started (GitHub Docs)](https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28)
- [Figma Community search — task management dashboard (live, 2026-10-05)](https://www.figma.com/community/search?resource_type=mixed&sort_by=relevancy&query=task%20management%20dashboard&editor_type=all)
- [ThemeForest — Taskify (live item page)](https://themeforest.net/item/taskify-task-management-nextjs-admin-dashboard-template/61127593)
- [ThemeForest — Mytask (live item page)](https://themeforest.net/item/mytask-hr-project-management-admin-template/31974551)
- [ThemeForest — Taskora (live item page)](https://themeforest.net/item/taskora-project-management-tailwind-css-next-js-admin-dashboard-template/58164858)
- [github.com/Kiranism/next-shadcn-dashboard-starter (live via GitHub API)](https://github.com/Kiranism/next-shadcn-dashboard-starter)
- [github.com/arhamkhnz/next-shadcn-admin-dashboard (live via GitHub API)](https://github.com/arhamkhnz/next-shadcn-admin-dashboard)
- [github.com/Phantas0s/devdash (live via GitHub API)](https://github.com/Phantas0s/devdash)
