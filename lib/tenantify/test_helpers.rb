# frozen_string_literal: true

module Tenantify
  module TestHelpers
    def with_tenant(tenant)
      Tenantify.switch_to(tenant) do
        yield
      end
    end

    def without_tenant
      Tenantify.without_tenant do
        yield
      end
    end

    def self.set_tenant(tenant)
      Tenantify.current_tenant = tenant
    end

    def self.clear_tenant
      Tenantify.current_tenant = nil
      Tenantify::Current.reset
    end
  end
end
