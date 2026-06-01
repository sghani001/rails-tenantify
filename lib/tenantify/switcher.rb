# frozen_string_literal: true

module Tenantify
  module Switcher
    module_function

    def switch_to(tenant, &block)
      Tenantify.switch_to(tenant, &block)
    end

    def without_tenant(&block)
      Tenantify.without_tenant(&block)
    end
  end
end
