# frozen_string_literal: true

module Todos
  module UseCases
  # "Adiar 1h" — silencia o lembrete da tarefa até o horário; a tarefa continua
  # na fila até ser concluída (decisão #7: adiar não move a tarefa, só para de lembrar).
  class SnoozeTodo
    def initialize(repository: Repositories::TodoRepository.new)
      @repository = repository
    end

    def call(id, por: 1.hour)
      todo = @repository.find(id)
      todo.snooze!(por.from_now)
      todo
    end
  end
  end
end
