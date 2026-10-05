# frozen_string_literal: true

require "rails_helper"

RSpec.describe Todos::Entities::Todo do
  describe "estados" do
    it "nasce pendente" do
      todo = create(:todo)
      expect(todo).to be_pendente
    end

    it "snooze silencia o lembrete sem tirar a tarefa da fila" do
      todo = create(:todo)
      todo.snooze!(2.minutes.from_now)

      expect(todo).to be_snoozed
      expect(todo.snoozed_until).to be > Time.current
      expect(Todos::Entities::Todo.lembraveis).to include(todo) # continua na fila
    end

    it "snoozed volta a ser notificável quando o horário vence" do
      todo = create(:todo)
      todo.snooze!(2.minutes.ago)

      expect(todo).to be_lembrete_ativo # snoozed vencido = lembrete ativo de novo
      expect(Todos::Entities::Todo.notificaveis_agora).to include(todo)
    end

    it "complete! marca como concluída e limpa o snooze" do
      todo = create(:todo)
      todo.snooze!(1.hour.from_now)
      todo.complete!

      expect(todo).to be_concluida
      expect(todo.snoozed_until).to be_nil
      expect(Todos::Entities::Todo.lembraveis).not_to include(todo)
    end
  end

  describe "scopes" do
    it "por_vencimento ordena snoozed pelo horário de retorno" do
      agora = create(:todo, title: "agora", snoozed_until: 5.minutes.from_now, status: :snoozed)
      depois = create(:todo, title: "depois", snoozed_until: 1.hour.from_now, status: :snoozed)

      titulos = Todos::Entities::Todo.lembraveis.por_vencimento.map(&:title)
      expect(titulos).to eq([ "agora", "depois" ])
    end

    it "notificaveis_agora exclui snoozed com horário no futuro" do
      create(:todo)
      create(:todo, snoozed_until: 1.hour.from_now, status: :snoozed)

      expect(Todos::Entities::Todo.notificaveis_agora.count).to eq(1)
    end
  end

  describe "validações" do
    it "exige título" do
      expect(build(:todo, title: nil)).not_to be_valid
    end
  end
end
