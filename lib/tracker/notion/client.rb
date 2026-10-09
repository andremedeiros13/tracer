# frozen_string_literal: true

require "net/http"
require "json"

module Tracker
  module Notion
    # Cliente HTTP puro do Notion (ADR 0001 — sem gem de terceiro no seam).
    # A superfície usada é pequena: GET database, POST query, (PATCH page).
    class Client
      BASE = "https://api.notion.com/v1"
      VERSION = "2022-06-28"

      def initialize(token:, database_id:)
        @token = token
        @database_id = database_id
      end

      def self.from_env
        new(token: ENV.fetch("TRACER_NOTION_TOKEN"),
            database_id: ENV.fetch("TRACER_NOTION_DATABASE_ID"))
      end

      def retrieve_database
        request(:Get, "/databases/#{@database_id}")
      end

      # Paginação por cursor (has_more/start_cursor, 100/página — API Free).
      def query_database(filter: nil)
        pages = []
        cursor = nil
        loop do
          body = request(:Post, "/databases/#{@database_id}/query",
                         body: { page_size: 100, start_cursor: cursor, filter: }.compact)
          pages.concat(body.fetch("results"))
          break unless body.fetch("has_more")
          cursor = body.fetch("next_cursor")
        end
        pages
      end

      private

      def request(method, path, body: nil)
        uri = URI("#{BASE}#{path}")
        req = Net::HTTP.const_get(method).new(uri)
        req["Authorization"] = "Bearer #{@token}"
        req["Notion-Version"] = VERSION
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body) if body

        resposta = com_retry_429 { Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) } }
        raise ApiError.new(resposta.code, resposta.body) unless resposta.is_a?(Net::HTTPSuccess)

        JSON.parse(resposta.body)
      end

      # Honra Retry-After no 429 (rate limit — API Free: 180 req/min).
      def com_retry_429(max_tentativas: 2)
        tentativas = 0
        loop do
          resposta = yield
          return resposta unless resposta.code == "429"
          raise ApiError.new(resposta.code, resposta.body) if tentativas >= max_tentativas

          sleep(resposta["Retry-After"]&.to_f || 1.0)
          tentativas += 1
        end
      end
    end
  end
end
