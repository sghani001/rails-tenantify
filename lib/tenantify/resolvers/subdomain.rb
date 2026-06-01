# frozen_string_literal: true

module Tenantify
  module Resolvers
    class Subdomain
      def initialize(exclude: %w[www], attribute: :subdomain)
        @exclude = Array(exclude)
        @attribute = attribute
      end

      def call(request)
        subdomain = request.subdomain
        return nil if subdomain.blank? || @exclude.include?(subdomain)

        Tenantify.tenant_class.find_by(@attribute => subdomain)
      end
    end
  end
end
