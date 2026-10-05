# frozen_string_literal: true

# Configuração de lembretes (frequência + período ativo) — persistida em SQLite.
class SettingsController < ApplicationController
  helper_method :hora_options

  def show
    @intervalo = Setting.get("notify_interval_minutes")
    @inicio = Setting.get("notify_active_start")
    @fim = Setting.get("notify_active_end")
  end

  def update
    Setting.set("notify_interval_minutes", params.require(:notify_interval_minutes))
    Setting.set("notify_active_start", params.require(:notify_active_start))
    Setting.set("notify_active_end", params.require(:notify_active_end))
    redirect_to settings_path
  end

  private

  def hora_options
    (6..22).map { |h| [ "#{format('%02d', h)}:00", "#{format('%02d', h)}:00" ] }
  end
end
