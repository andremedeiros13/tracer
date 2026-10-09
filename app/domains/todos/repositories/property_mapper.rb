# frozen_string_literal: true

module Todos
  module Repositories
    # Mapper Notion page JSON → Todos::Entities::Todo.
    # Falha rápido em propriedade/opção desconhecida (o boot valida o schema
    # contra NotionSchema antes — ADR 0001).
    class PropertyMapper
      STATUS = NotionSchema::PROPERTIES.fetch("Status").fetch(:options)
      ORIGEM = NotionSchema::PROPERTIES.fetch("Origem").fetch(:options)

      def from_page(page)
        props = page.fetch("properties")
        Entities::Todo.new(
          page_id: page.fetch("id"),
          title: props.fetch("Name").fetch("title").map { |t| t.fetch("plain_text") }.join,
          status: STATUS.fetch(props.fetch("Status").fetch("status").fetch("name")),
          # Origem vazia (select null) = tarefa criada direto no Notion → manual.
          origin: ORIGEM.fetch(props.dig("Origem", "select", "name"), :manual),
          snoozed_until: parse_data(props.dig("Snoozed até", "date", "start")),
          created_at: Time.zone.parse(page.fetch("created_time")),
          last_edited_time: Time.zone.parse(page.fetch("last_edited_time"))
        )
      end

      private

      # Date com hora vem ISO-8601 UTC; date-only ("2026-10-09") vira início
      # do dia. "Snoozed até" deve ter hora para snooze preciso.
      def parse_data(valor)
        return nil if valor.nil?

        valor.length == 10 ? Time.zone.parse("#{valor} 00:00") : Time.zone.parse(valor)
      end
    end
  end
end
