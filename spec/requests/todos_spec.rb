# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Painel (fila de atenção)" do
  describe "GET /" do
    it "renderiza a fila com as pendências" do
      create(:todo, title: "Tarefa visível", origin: :via_jira)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("O que precisa de você")
      expect(response.body).to include("Tarefa visível")
      expect(response.body).to include("via Jira")
    end

    it "renderiza a sidebar com os módulos futuros" do
      get root_path

      expect(response.body).to include("Entregas do dia")
      expect(response.body).to include("1-on-1")
      expect(response.body).to include("Configurações")
    end
  end

  describe "POST /todos" do
    it "cria tarefa manual" do
      expect { post todos_path, params: { title: "Manual da UI" } }
        .to change(Todos::Entities::Todo, :count).by(1)

      expect(Todos::Entities::Todo.last).to be_origin_manual
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /todos/:id/complete" do
    it "conclui a tarefa" do
      todo = create(:todo)

      patch complete_todo_path(todo)

      expect(todo.reload).to be_concluida
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /todos/:id/snooze" do
    it "silencia o lembrete" do
      todo = create(:todo)

      patch snooze_todo_path(todo)

      expect(todo.reload).to be_snoozed
      expect(Todos::Entities::Todo.lembraveis).to include(todo)
    end
  end
end

RSpec.describe "Configuração de lembretes" do
  describe "GET /settings" do
    it "renderiza o formulário com os defaults" do
      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Frequência")
      expect(response.body).to include("Período ativo")
    end
  end

  describe "PATCH /settings" do
    it "persiste frequência e período ativo" do
      patch settings_path, params: {
        notify_interval_minutes: "30",
        notify_active_start: "08:00",
        notify_active_end: "20:00"
      }

      expect(Setting.get("notify_interval_minutes")).to eq("30")
      expect(Setting.get("notify_active_start")).to eq("08:00")
      expect(Setting.get("notify_active_end")).to eq("20:00")
      expect(response).to redirect_to(settings_path)
    end
  end
end
