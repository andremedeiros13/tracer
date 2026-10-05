FactoryBot.define do
  factory :todo, class: "Todos::Entities::Todo" do
    title { "Tarefa de exemplo" }
    origin { :manual }
    status { :pendente }
    notified_count { 0 }
  end
end
