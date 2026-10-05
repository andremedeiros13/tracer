# frozen_string_literal: true

module Todos
  module Repositories
    # Repository do contexto Todos: interface de persistência para os use cases.
    # Delega ao ActiveRecord (SQLite) — os use cases não falam com o ORM direto.
    class TodoRepository
      def lembraveis_por_vencimento
        Entities::Todo.lembraveis.por_vencimento
      end

      def notificaveis_agora
        Entities::Todo.notificaveis_agora.por_vencimento
      end

      def concluidas_hoje
        Entities::Todo.concluida.where(updated_at: Time.current.all_day)
      end

      def find(id)
        Entities::Todo.find(id)
      end

      def create!(attributes)
        Entities::Todo.create!(attributes)
      end
    end
  end
end
