# frozen_string_literal: true

require "rails_helper"

RSpec.describe Todos::UseCases::SnoozeTodo do
  it "silencia o lembrete por 1h sem tirar a tarefa da fila" do
    todo = create(:todo)

    result = described_class.new.call(todo.id, por: 1.hour)

    expect(result.reload).to be_snoozed
    expect(result.snoozed_until).to be_within(5.seconds).of(1.hour.from_now)
    expect(Todos::Entities::Todo.lembraveis).to include(result) # continua na fila
  end
end

RSpec.describe Todos::UseCases::CompleteTodo do
  it "marca a tarefa como concluída" do
    todo = create(:todo)

    result = described_class.new.call(todo.id)

    expect(result.reload).to be_concluida
  end
end

RSpec.describe Todos::UseCases::CreateTodo do
  it "cria tarefa manual pendente" do
    result = described_class.new.call("Nova tarefa")

    expect(result).to be_pendente
    expect(result).to be_origin_manual
    expect(result.title).to eq("Nova tarefa")
  end
end

RSpec.describe Todos::UseCases::BuildAttentionQueue do
  it "separa pendências (ordenadas por vencimento) e concluídas de hoje" do
    concluida = create(:todo, status: :concluida)
    pendente = create(:todo)

    fila = described_class.new.call

    expect(fila[:pendencias]).to include(pendente)
    expect(fila[:pendencias]).not_to include(concluida)
    expect(fila[:concluidas]).to include(concluida)
  end
end
