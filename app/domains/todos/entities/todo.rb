# frozen_string_literal: true

module Todos
  module Entities
    # Entity do domínio: uma tarefa (To-Do) com origem e estado.
    #
    # Estados: pendente -> snoozed (até X; a tarefa continua na fila, só para de
    # lembrar) -> concluída. Origens: manual, via_jira, via_transcricao.
    class Todo < ApplicationRecord
      self.table_name = "todos"

      enum :origin, { manual: 0, via_jira: 1, via_transcricao: 2 }, prefix: true
      # sem prefix no status: pendente?/snoozed?/concluida? (valores únicos)
      enum :status, { pendente: 0, snoozed: 1, concluida: 2 }

      validates :title, presence: true

      scope :lembraveis, -> { where(status: [ :pendente, :snoozed ]) }

      # A fila de atenção ordena pelo que vence primeiro: snoozed volta no horário.
      scope :por_vencimento, lambda {
        order(Arel.sql("COALESCE(snoozed_until, created_at) ASC"))
      }

      # Pendências que o ciclo de notificação considera agora (não-snoozed).
      scope :notificaveis_agora, lambda {
        lembraveis.where(
          "status = :pendente OR (status = :snoozed AND snoozed_until <= :now)",
          pendente: statuses[:pendente], snoozed: statuses[:snoozed], now: Time.current
        )
      }

      def lembrete_ativo?
        pendente? || (snoozed? && snoozed_until <= Time.current)
      end

      def snooze!(ate)
        update!(status: :snoozed, snoozed_until: ate)
      end

      def complete!
        update!(status: :concluida, snoozed_until: nil)
      end
    end
  end
end
