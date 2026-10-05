# Seeds (spec §3.3): tarefas de exemplo pré-criadas nas TRÊS origens —
# exercita a UI das fontes sem uma linha de integração. Idempotente.

TODOS_EXEMPLO = [
  { title: "Revisar PR — auth-service", origin: :via_jira },
  { title: "Combinado 1-on-1: agendar pair programming", origin: :via_transcricao },
  { title: "Enviar resumo da weekly para o time", origin: :manual }
].freeze

TODOS_EXEMPLO.each do |attrs|
  Todos::Entities::Todo.find_or_create_by!(title: attrs[:title]) do |todo|
    todo.origin = attrs[:origin]
    todo.status = :pendente
    todo.notified_count = 0
  end
end
