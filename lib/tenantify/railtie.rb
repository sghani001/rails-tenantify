# frozen_string_literal: true

require "rails/railtie"

module Tenantify
  class Railtie < Rails::Railtie
    initializer "tenantify.active_record" do
      ActiveSupport.on_load(:active_record) do
        include Tenantify::Scoped
      end
    end

    initializer "tenantify.action_controller" do
      ActiveSupport.on_load(:action_controller) do
        include Tenantify::Controller
      end
    end

    initializer "tenantify.sidekiq" do
      if defined?(Sidekiq)
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
end
