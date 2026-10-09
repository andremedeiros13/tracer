# frozen_string_literal: true

module Todos
  module Repositories
    # Fonte única de verdade dos nomes/tipos/opções do Database "To-Dos" no
    # Notion — o mapper e o validador de boot derivam daqui (ADR 0001: o
    # Database é criado manualmente com exatamente essas propriedades).
    module NotionSchema
      DATABASE_NAME = "To-Dos"

      PROPERTIES = {
        "Name" => { type: "title" },
        "Status" => { type: "status", options: {
          "Pendente" => :pendente, "Em andamento" => :snoozed, "Concluída" => :concluida
        } },
        "Origem" => { type: "select", options: {
          "Manual" => :manual, "Via Jira" => :via_jira, "Via Transcrição" => :via_transcricao
        } },
        "Snoozed até" => { type: "date" }
      }.freeze
    end
  end
end
