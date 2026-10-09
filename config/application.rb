require_relative "boot"

require "rails"
# Pick the frameworks you want (ADR 0001 — Notion é a UI e a fonte da verdade;
# o backend expõe só o health check):
require "action_controller/railtie"
# require "active_storage/engine"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
# require "action_view/railtie"
# require "active_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tracker
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Zeitwerk já autoloada app/* subdiretórios (Rails 8) — app/domains/todos/*
    # é carregado sem config extra. Edge: app/domains/*/README.md e CONTEXT.md
    # não são .rb, ignorados naturalmente.
    config.time_zone = "America/Sao_Paulo"
  end
end
