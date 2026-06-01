# frozen_string_literal: true

module Tenantify
  module Resolvers
    class Header
      def initialize(header: "X-Tenant-ID")
        @header = header
      end

      def call(request)
        tenant_id = request.headers[@header]
        return nil if tenant_id.blank?

        Tenantify.tenant_class.find_by(id: tenant_id)
      end
    end
  end
end
