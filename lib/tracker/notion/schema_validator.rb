# frozen_string_literal: true

module Tracker
  module Notion
    # Valida as propriedades do Database "To-Dos" contra o schema esperado
    # (ADR 0001: valida no boot e falha cedo se divergir).
    class SchemaValidator
      def initialize(client:, expected:)
        @client = client
        @expected = expected
      end

      def validate!
        atual = @client.retrieve_database.fetch("properties")
        divergencias = []
        @expected.each do |nome, esperado|
          if (prop = atual[nome]).nil?
            divergencias << "propriedade '#{nome}' ausente"
            next
          end
          if prop["type"] != esperado[:type].to_s
            divergencias << "propriedade '#{nome}': tipo '#{prop["type"]}' != '#{esperado[:type]}'"
          end
          next unless (esperadas = esperado[:options]&.keys)

          opcoes_atuais = (prop.dig(prop["type"], "options") || []).map { |opcao| opcao["name"] }
          if (faltando = esperadas - opcoes_atuais).any?
            divergencias << "propriedade '#{nome}': opções ausentes #{faltando.join(", ")}"
          end
        end
        return if divergencias.empty?

        raise SchemaError, "Database do Notion diverge do schema esperado:\n#{divergencias.join("\n")}"
      end
    end
  end
end
