# frozen_string_literal: true

# Rails may load this file before lib/tenantify.rb; ensure the full API is defined.
require "tenantify" unless Tenantify.respond_to?(:configure)

require "rails/railtie"

module Tenantify
  class Railtie < Rails::Railtie
    initializer "tenantify.action_controller" do
      ActiveSupport.on_load(:action_controller) do
        include Tenantify::Controller
      end
    end

    initializer "tenantify.sidekiq" do
      next unless defined?(Sidekiq)

      require_relative "middleware/sidekiq"

      Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.add Tenantify::Middleware::SidekiqClient
        end
      end

      Sidekiq.configure_server do |config|
        config.client_middleware do |chain|
          chain.add Tenantify::Middleware::SidekiqClient
        end
        config.server_middleware do |chain|
          chain.add Tenantify::Middleware::SidekiqServer
        end
      end
    end
  end
end
