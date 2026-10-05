# frozen_string_literal: true

module Todos
  module UseCases
  # A fila de atenção: pendências ordenadas pelo que vence primeiro.
  # Snoozed volta no horário; concluídas não aparecem na fila (aparecem no rodapé).
  class BuildAttentionQueue
    def initialize(repository: Repositories::TodoRepository.new)
      @repository = repository
    end

    def call
      { pendencias: @repository.lembraveis_por_vencimento, concluidas: @repository.concluidas_hoje }
    end
  end
  end
end
