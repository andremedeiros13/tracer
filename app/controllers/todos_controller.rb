# frozen_string_literal: true

# Controller thin — delega para os use cases do contexto Todos.
class TodosController < ApplicationController
  helper_method :label_da_origem

  def index
    fila = Todos::UseCases::BuildAttentionQueue.new.call
    @pendencias = fila[:pendencias]
    @concluidas = fila[:concluidas]
  end

  def create
    Todos::UseCases::CreateTodo.new.call(params.require(:title))
    redirect_to root_path
  end

  def complete
    Todos::UseCases::CompleteTodo.new.call(params[:id])
    redirect_to root_path
  end

  def snooze
    Todos::UseCases::SnoozeTodo.new.call(params[:id], por: 1.hour)
    redirect_to root_path
  end

  private

  def label_da_origem(origem)
    { "manual" => "manual", "via_jira" => "via Jira", "via_transcricao" => "1-on-1" }.fetch(origem, origem)
  end
end
