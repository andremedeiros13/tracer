# frozen_string_literal: true

module Todos
  module UseCases
  # O ciclo do daemon: agrega as pendências (não-snoozed) e dispara **uma**
  # notificação nativa com o resumo — "3 pendências: code review, 1-on-1, manual".
  # Resumo único por ciclo (decisão #7): quebra o hiperfoco sem bombardear.
  class NotifyPendingTodos
    def initialize(repository: Repositories::TodoRepository.new, notifier: Tracker::NativeNotifier.new)
      @repository = repository
      @notifier = notifier
    end

    def call
      pendencias = @repository.notificaveis_agora
      return if pendencias.empty?

      resumo = "#{pendencias.size} pendência#{pendencias.size > 1 ? 's' : ''}: #{resumo_das_origens(pendencias)}"
      @notifier.notify("Tracker", resumo)
      resumo
    end

    private

    def resumo_das_origens(pendencias)
      origens = pendencias.map(&:origin).tally
                      .sort_by { |_, count| -count }
                      .map { |origem, count| "#{label_da_origem(origem)}#{count > 1 ? " (#{count})" : ''}" }
      origens.join(", ")
    end

    def label_da_origem(origem)
      { manual: "manual", via_jira: "via Jira", via_transcricao: "1-on-1" }.fetch(origem, origem)
    end
  end
  end
end
