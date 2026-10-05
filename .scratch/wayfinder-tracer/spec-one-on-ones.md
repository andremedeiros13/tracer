# Spec: Módulo de 1-on-1 — histórico de reuniões e parsing de transcrições

> Especificação de implementação. Decisões do
> [Wayfinder map: Tracer — módulos de tracking e 1-on-1](https://github.com/andremedeiros13/tracer/issues/9)
> (formato #14, protótipo #13, exemplos #3 do mapa anterior).

## 1. O quê

Completar o bounded context **OneOnOnes** (hoje fronteira nomeada em
`app/domains/one_on_ones/`): importar transcrições de reuniões do Google Meet
("Anotações do Gemini"), extrair **resumo + action items** nativamente (sem
IA/LLM), deixar o usuário **revisar e marcar os seus** com confirmação, converter
em To-Dos, e manter o **histórico completo** das reuniões na página de 1-on-1.

## 2. Decisões fundamentais (do mapa)

| Decisão | Resposta | Ticket |
|---|---|---|
| Importação | **upload pela UI** — botão "Importar transcrição" (arquivo .md do Meet) | [#14](https://github.com/andremedeiros13/tracer/issues/14) |
| Escopo do parsing | **resumo + action items** — detalhes com timestamps ficam no arquivo original | [#14](https://github.com/andremedeiros13/tracer/issues/14) |
| Atribuição | **revisão na importação** — parser extrai todos; usuário marca quais são dele | [#14](https://github.com/andremedeiros13/tracer/issues/14) |
| Conversão | **com confirmação** — marca os seus + confirma a conversão em um clique | [#14](https://github.com/andremedeiros13/tracer/issues/14) |
| Histórico | **lista completa de reuniões** (data, título, participantes, resumo, action items, link do arquivo) | [#14](https://github.com/andremedeiros13/tracer/issues/14) |
| UI | **variante A — reuniões empilhadas** (todas visíveis) | [#13](https://github.com/andremedeiros13/tracer/issues/13) |

## 3. Arquitetura (DDD no contexto one_on_ones)

```
app/domains/one_on_ones/
├── entities/
│   ├── meeting.rb          (Meeting: data, título, participantes, resumo,
│   │                        arquivo_original, consolidado)
│   └── action_item.rb      (ActionItem: descrição, quem, marcado_como_meu,
│                            convertido, referência à reunião)
├── repositories/
│   ├── meeting_repository.rb
│   └── action_item_repository.rb
├── use_cases/
│   ├── import_transcription.rb   (upload → parse → cria Meeting + ActionItems pendentes)
│   ├── parse_transcription.rb    (o parser nativo — puro, sem IA)
│   └── convert_action_items.rb   (marca os seus + confirma → cria To-Dos)
└── CONTEXT.md
```

- **Entity `Meeting`**: `data` (date), `titulo`, `participantes` (lista),
  `resumo` (texto), `arquivo_original` (nome/caminho do .md), timestamps
- **Entity `ActionItem`**: `descricao`, `quem` (nome entre colchetes da
  transcrição), `marcado_como_meu` (bool — a revisão do usuário), `convertido`
  (bool), referência à `Meeting` e ao `Todo` criado (quando convertido)
- **Use cases** (`.call`):
  - `ImportTranscription` — recebe o conteúdo do .md, chama o parser, cria a
    Meeting + os ActionItems (não-marcados, não-convertidos)
  - `ParseTranscription` — **puro**: extrai reuniões (múltiplas por arquivo),
    resumo e action items da estrutura regular do Meet
  - `ConvertActionItems` — recebe os ids marcados como seus, cria To-Dos
    (origem `via_transcricao`, com link para a reunião) e marca `convertido`

## 4. O parser nativo (sem IA/LLM)

Formato real verificado (exemplos no
[ticket #3 do mapa anterior](https://github.com/andremedeiros13/tracer/issues/3) —
fonte de verdade e casos de teste):

- **Markdown exportado pelo Google Meet** ("Anotações do Gemini"); **múltiplas
  reuniões por arquivo** (delimitadas por data + `## título`)
- Estrutura por reunião (regular, detectável nativamente):
  - Cabeçalho: data (ex: `set. 23, 2026`) + título (`## ...`) + convidados
    (mailto: links)
  - `### Resumo` — bullets dos temas principais → vira o `resumo`
  - `### Decisões` (quando há) — bullets → parte do resumo
  - `### Próximas etapas` — **checkboxes** `- [ ] [Nome Completo] Descrição: detalhe`
    → vira ActionItems (`quem` = nome entre colchetes, `descricao` = o resto)
  - `### Detalhes` + transcrição crua (timestamps, falantes) → **ignorado**
    (fica no arquivo original)
- Casos de teste: os 2 exemplos reais (Provisionamento 09/04, 1:1 André/Spalenza 23/09)

## 5. Fluxo de revisão (painel)

1. **Importar**: botão "Importar transcrição" (file input .md) na página de 1-on-1
2. **Revisar**: o painel mostra a reunião extraída (data, título, participantes,
   resumo) + os action items com o dono — o usuário **marca os seus** (checkbox
   por item); o botão atualiza "Converter N em To-Dos"
3. **Confirmar**: um clique — os marcados viram To-Dos (aparecem na fila de
   atenção com origem "1-on-1"); a reunião entra no histórico com os action
   items (convertidos: badge; não-convertidos: visíveis com o dono)
4. **Descartar**: cancela a revisão (nada é gravado)

## 6. Painel

- **Página de 1-on-1** (substitui a página "em breve"):
  - **Caixa de importação** no topo (arraste o .md ou escolha o arquivo)
  - **Caixa de revisão** (após o upload, borda accent): resumo + action items
    com dono + checkboxes + "Converter N em To-Dos" + Descartar
  - **Histórico**: reuniões empilhadas ordenadas por data (mais recente
    primeiro) — data, título, resumo, action items (convertidos: riscado +
    badge "convertido"; não-convertidos: visíveis com o dono), link
    "Arquivo original"
  - Mesma sidebar validada; conteúdo centralizado (max-width 900px)
- Routes: `GET /one_on_ones` (histórico), `POST /one_on_ones/import` (upload),
  `POST /one_on_ones/:meeting_id/convert` (confirmação), `DELETE` (descartar)

## 7. Qualidade

- **RuboCop + rubocop-rails** (config existente)
- **RSpec + factory_bot**: **specs do parser com os 2 exemplos reais como
  fixtures** (casos de teste de verdade — múltiplas reuniões, checkboxes com
  dono, seções), specs dos use cases de importação/conversão, request specs
  do fluxo de revisão
- **Sem IA/LLM**: o parser é código puro — sem chamadas externas

## 8. Critérios de aceite

1. Importar um .md real do Meet → a revisão mostra a reunião + action items
   com donos corretos (testado com os 2 exemplos reais)
2. Marcar os seus + confirmar → To-Dos aparecem na fila de atenção com
   origem "1-on-1" e link para a reunião
3. Histórico mostra as reuniões importadas com action items e link do arquivo
4. Descartar não grava nada
5. Specs verdes (parser validado contra os exemplos reais) + RuboCop limpo
