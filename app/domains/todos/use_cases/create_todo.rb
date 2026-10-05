# frozen_string_literal: true

module Todos
  module UseCases
  # Criação manual pela UI (origem: manual).
  class CreateTodo
    def initialize(repository: Repositories::TodoRepository.new)
      @repository = repository
    end

    def call(title)
      @repository.create!(title: title, origin: :manual, status: :pendente, notified_count: 0)
    end
  end
  end
end
