# frozen_string_literal: true

module Tenantify
  module Controller
    extend ActiveSupport::Concern

    RESOLVERS = {
      subdomain: Resolvers::Subdomain,
      header: Resolvers::Header
    }.freeze

    class_methods do
      def set_tenant_by(resolver_type, **options)
        before_action(**options.slice(:only, :except, :if, :unless)) do
          resolve_and_set_tenant(resolver_type, options)
        end
      end
    end

    private

    def resolve_and_set_tenant(resolver_type, options)
      resolver_class = Tenantify::Controller::RESOLVERS[resolver_type]
      raise ArgumentError, "Unknown Tenantify resolver type: #{resolver_type}" unless resolver_class

      resolver = build_resolver(resolver_class, resolver_type, options)
      tenant = resolver.call(request)

      if tenant
        Tenantify.current_tenant = tenant
      else
        handle_tenant_not_found(options)
      end
    end

    def build_resolver(resolver_class, resolver_type, options)
      case resolver_type
      when :subdomain
        resolver_class.new(
          exclude: options[:exclude] || %w[www],
          attribute: options[:attribute] || :subdomain
        )
      when :header
        resolver_class.new(header: options[:header] || "X-Tenant-ID")
      else
        resolver_class.new
      end
    end

    def handle_tenant_not_found(options)
      behavior = Tenantify.configuration.on_tenant_not_found

      case behavior
      when :raise
        raise TenantNotFoundError, "Tenant could not be resolved for request to #{request.url}"
      when :redirect
        redirect_path = options[:fallback] || "/"
        redirect_to(redirect_path)
      when :null_tenant
        Tenantify.current_tenant = nil
      else
        raise TenantNotFoundError, "Tenant could not be resolved for request to #{request.url}"
      end
    end
  end
end
