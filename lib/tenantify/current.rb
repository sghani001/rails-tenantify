# frozen_string_literal: true

require "active_support/current_attributes"

module Tenantify
  class Current < ActiveSupport::CurrentAttributes
    attribute :tenant
    attribute :tenant_scope_disabled
  end
end
