# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"

require_relative "tenantify/version"
require_relative "tenantify/errors"
require_relative "tenantify/current"
require_relative "tenantify/configuration"
require_relative "tenantify/scoped"
require_relative "tenantify/controller"
require_relative "tenantify/job"
require_relative "tenantify/test_helpers"
require_relative "tenantify/railtie" if defined?(Rails)

module Tenantify
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def current_tenant
      Current.tenant
    end

    def current_tenant=(tenant)
      # Check if we are changing the tenant when it's already set and audit_overrides is configured
      if Current.tenant && tenant && Current.tenant != tenant
        message = "Unsafe tenant override attempted: changing tenant from #{Current.tenant.id} to #{tenant.id}"
        if configuration.audit_overrides == :raise
          raise TenantOverrideError, message
        elsif configuration.audit_overrides == :log
          if defined?(Rails) && Rails.logger
            Rails.logger.warn("[Tenantify] #{message}")
          else
            warn("[Tenantify] #{message}")
          end
        end
      end
      Current.tenant = tenant
    end

    def current_tenant_id
      current_tenant&.id
    end

    def tenant_scoped?
      !Current.tenant_scope_disabled
    end

    def switch_to(tenant)
      old_tenant = Current.tenant
      Current.tenant = tenant
      begin
        yield
      ensure
        Current.tenant = old_tenant
      end
    end

    def without_tenant
      old_disabled = Current.tenant_scope_disabled
      Current.tenant_scope_disabled = true
      begin
        yield
      ensure
        Current.tenant_scope_disabled = old_disabled
      end
    end

    def tenant_class
      class_name = configuration.tenant_model
      raise Tenantify::Error, "tenant_model is not configured. Define it in Tenantify.configure." unless class_name
      class_name.constantize
    end
  end
end
