# frozen_string_literal: true

require "rails_helper"

RSpec.describe Todos::Repositories::TodoRepository do
  let(:client) { instance_double(Tracker::Notion::Client) }
  let(:repository) { described_class.new(client: client, mapper: Todos::Repositories::PropertyMapper.new) }

  def page_notion(titulo:, status:, snoozed_until: nil, origem: "Manual")
    {
      "id" => "page-#{titulo}",
      "created_time" => "2026-10-09T12:00:00.000Z",
      "last_edited_time" => "2026-10-09T12:00:00.000Z",
      "properties" => {
        "Name" => { "type" => "title", "title" => [ { "plain_text" => titulo } ] },
        "Status" => { "type" => "status", "status" => { "name" => status } },
        "Origem" => { "type" => "select", "select" => { "name" => origem } },
        "Snoozed até" => { "type" => "date", "date" => snoozed_until ? { "start" => snoozed_until } : nil }
      }
    }
  end

  before do
    allow(client).to receive(:query_database).and_return([
      page_notion(titulo: "agora", status: "Pendente"),
      page_notion(titulo: "snoozed futuro", status: "Snoozed", snoozed_until: "2099-01-01T12:00:00.000Z"),
      page_notion(titulo: "snoozed vencido", status: "Snoozed", snoozed_until: "2020-01-01T12:00:00.000Z")
    ])
  end

  describe "#notificaveis_agora" do
    it "exclui snoozed com horário no futuro e inclui vencido" do
      titulos = repository.notificaveis_agora.map(&:title)

      expect(titulos).to eq([ "snoozed vencido", "agora" ])
    end

    it "consulta o Notion com filtro server-side no Status" do
      repository.notificaveis_agora

      expect(client).to have_received(:query_database).with(
        filter: { or: [
          { property: "Status", status: { equals: "Pendente" } },
          { property: "Status", status: { equals: "Snoozed" } }
        ] }
      )
    end

    it "ordenada pelo que vence primeiro (snoozed volta no horário)" do
      allow(client).to receive(:query_database).and_return([
        page_notion(titulo: "criada antes", status: "Pendente"),
        page_notion(titulo: "snoozed vencido", status: "Snoozed", snoozed_until: "2020-01-01T12:00:00.000Z")
      ])

      expect(repository.notificaveis_agora.map(&:title)).to eq([ "snoozed vencido", "criada antes" ])
    end
  end
end
