# frozen_string_literal: true

module Tenantify
  class Error < StandardError; end

  class TenantNotFoundError < Error; end
  class TenantMismatchError < Error; end
  class TenantOverrideError < Error; end
end
