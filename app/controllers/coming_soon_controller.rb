# frozen_string_literal: true

# Módulos futuros (navegação visível, implementação pós-POC).
class ComingSoonController < ApplicationController
  def entregas
    @modulo = "Entregas do dia"
  end

  def one_on_ones
    @modulo = "1-on-1"
  end
end
