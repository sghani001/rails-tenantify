# frozen_string_literal: true

module Tenantify
  class Configuration
    attr_accessor :tenant_model, :on_tenant_not_found, :audit_overrides

    def initialize
      @tenant_model = nil
      @on_tenant_not_found = :raise
      @audit_overrides = :log
    end
  end
end
