Rails.application.routes.draw do
  # ADR 0001 — a UI é o Notion; o backend expõe só o health check.
  get "up", to: "rails/health#show", as: :rails_health_check
end
