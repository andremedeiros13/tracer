# frozen_string_literal: true

# Configuração persistida (SQLite, key/value): frequência e período ativo das
# notificações — configuráveis pela UI.
class Setting < ApplicationRecord
  DEFAULTS = {
    "notify_interval_minutes" => "45",
    "notify_active_start" => "09:00",
    "notify_active_end" => "18:00"
  }.freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS[key]
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.update!(value: value)
    value
  end
end
