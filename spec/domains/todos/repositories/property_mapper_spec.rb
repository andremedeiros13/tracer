# frozen_string_literal: true

require "rails_helper"

RSpec.describe Todos::Repositories::PropertyMapper do
  def page(props_overrides = {})
    {
      "id" => "page-uuid",
      "created_time" => "2026-10-09T12:00:00.000Z",
      "last_edited_time" => "2026-10-09T14:30:00.000Z",
      "properties" => {
        "Name" => { "type" => "title", "title" => [ { "plain_text" => "Revisar PR — auth-service" } ] },
        "Status" => { "type" => "status", "status" => { "name" => "Pendente" } },
        "Origem" => { "type" => "select", "select" => { "name" => "Via Jira" } },
        "Snoozed até" => { "type" => "date", "date" => nil }
      }.merge(props_overrides)
    }
  end

  it "mapeia os campos da page para a entity" do
    t = described_class.new.from_page(page)

    expect(t.page_id).to eq("page-uuid")
    expect(t.title).to eq("Revisar PR — auth-service")
    expect(t.status).to eq(:pendente)
    expect(t.origin).to eq(:via_jira)
    expect(t.snoozed_until).to be_nil
    expect(t.created_at).to eq(Time.zone.parse("2026-10-09T12:00:00.000Z"))
    expect(t.last_edited_time).to eq(Time.zone.parse("2026-10-09T14:30:00.000Z"))
  end

  it "mapeia Snoozed até com hora (ISO-8601 UTC)" do
    props = { "Snoozed até" => { "type" => "date", "date" => { "start" => "2026-10-09T15:00:00.000Z", "end" => nil } } }

    expect(described_class.new.from_page(page(props)).snoozed_until)
      .to eq(Time.zone.parse("2026-10-09T15:00:00.000Z"))
  end

  it "date-only vira início do dia" do
    props = { "Snoozed até" => { "type" => "date", "date" => { "start" => "2026-10-09", "end" => nil } } }

    t = described_class.new.from_page(page(props))
    expect(t.snoozed_until).to eq(Time.zone.parse("2026-10-09 00:00"))
  end

  it "Origem vazia (select null) vira :manual" do
    props = { "Origem" => { "type" => "select", "select" => nil } }

    expect(described_class.new.from_page(page(props)).origin).to eq(:manual)
  end

  it "falha rápido em opção de Status desconhecida" do
    props = { "Status" => { "type" => "status", "status" => { "name" => "Inexistente" } } }

    expect { described_class.new.from_page(page(props)) }.to raise_error(KeyError)
  end
end
