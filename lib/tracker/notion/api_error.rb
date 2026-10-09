# frozen_string_literal: true

module Tracker
  module Notion
    class ApiError < Error
      def initialize(code, body) = super("Notion API #{code}: #{body}")
    end
  end
end
