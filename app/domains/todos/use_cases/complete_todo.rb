# frozen_string_literal: true

module Todos
  module UseCases
  # Marca a tarefa como concluída.
  class CompleteTodo
    def initialize(repository: Repositories::TodoRepository.new)
      @repository = repository
    end

    def call(id)
      todo = @repository.find(id)
      todo.complete!
      todo
    end
  end
  end
end
