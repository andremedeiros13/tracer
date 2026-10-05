Rails.application.routes.draw do
  # Painel (fila de atenção) + ações das tarefas + configuração de lembretes.
  root "todos#index"

  post "todos", to: "todos#create"
  patch "todos/:id/complete", to: "todos#complete", as: :complete_todo
  patch "todos/:id/snooze", to: "todos#snooze", as: :snooze_todo

  get "settings", to: "settings#show", as: :settings
  patch "settings", to: "settings#update"

  # Módulos futuros (navegação visível, implementação pós-POC)
  get "entregas", to: "coming_soon#entregas", as: :entregas
  get "one_on_ones", to: "coming_soon#one_on_ones", as: :one_on_ones
end
