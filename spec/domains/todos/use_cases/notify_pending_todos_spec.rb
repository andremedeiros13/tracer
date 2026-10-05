# frozen_string_literal: true

require "rails_helper"

RSpec.describe Todos::UseCases::NotifyPendingTodos do
  let(:notifier) { instance_double(Tracer::NativeNotifier) }
  let(:use_case) { described_class.new(notifier: notifier) }

  describe "#call" do
    it "dispara UMA notificação com o resumo das pendências" do
      create(:todo, title: "a", origin: :via_jira)
      create(:todo, title: "b", origin: :via_jira)
      create(:todo, title: "c", origin: :manual)

      expect(notifier).to receive(:notify)
        .with("Tracer", "3 pendências: via Jira (2), manual")

      resumo = use_case.call
      expect(resumo).to eq("3 pendências: via Jira (2), manual")
    end

    it "não notifica quando não há pendências" do
      create(:todo, status: :concluida)
      create(:todo, snoozed_until: 1.hour.from_now, status: :snoozed)

      expect(notifier).not_to receive(:notify)
      expect(use_case.call).to be_nil
    end

    it "snoozed vencido entra no ciclo" do
      create(:todo, snoozed_until: 1.minute.ago, status: :snoozed)

      expect(notifier).to receive(:notify).with("Tracer", "1 pendência: manual")
      use_case.call
    end

    it "incrementa o contador de lembretes disparados" do
      todo = create(:todo)
      allow(notifier).to receive(:notify)

      use_case.call
      expect(todo.reload.notified_count).to eq(1)
    end
  end
end
