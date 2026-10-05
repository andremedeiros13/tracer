# frozen_string_literal: true

# Scheduler do daemon (spec §3.1): thread dentro do `rails server` que dispara
# `Todos::UseCases::NotifyPendingTodos` no intervalo configurado pelo usuário, respeitando
# o período ativo. Thread daemon — morre com o processo do servidor.
#
# Desabilitável em testes/console: Tracer::Scheduler.disabled = true
module Tracer
  class Scheduler
    class << self
      attr_accessor :disabled
    end
    self.disabled = false

    INTERVALO_MINIMO_SEGUNDOS = 60

    def start
      Thread.new do
        Thread.current.name = "tracer-scheduler"
        loop do
          disparar_se_no_periodo
          sleep intervalo_segundos
        rescue StandardError => e
          Rails.logger.error("[tracer-scheduler] #{e.class}: #{e.message}")
        end
      end
    end

    private

    def intervalo_segundos
      [ Setting.get("notify_interval_minutes").to_i * 60, INTERVALO_MINIMO_SEGUNDOS ].max
    end

    def disparar_se_no_periodo
      return unless periodo_ativo?

      Todos::UseCases::NotifyPendingTodos.new.call
    end

    def periodo_ativo?
      agora = Time.current
      inicio = parse_hora(Setting.get("notify_active_start"))
      fim = parse_hora(Setting.get("notify_active_end"))
      agora.between?(agora.change(hour: inicio.first, min: inicio.last),
                     agora.change(hour: fim.first, min: fim.last))
    end

    def parse_hora(hora)
      hora.split(":").map(&:to_i)
    end
  end
end

Rails.application.config.after_initialize do
  next if defined?(Rails::Console) || Rails.env.test? || Tracer::Scheduler.disabled

  Tracer::Scheduler.new.start
end
