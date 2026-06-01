# frozen_string_literal: true

module Tenantify
  module Controller
    extend ActiveSupport::Concern

    class_methods do
      def set_tenant_by(resolver_type, options = {})
        before_action(options.except(:exclude, :fallback)) do
          resolve_and_set_tenant(resolver_type, options)
        end
      end
    end

    private

    def resolve_and_set_tenant(resolver_type, options)
      tenant = nil

      case resolver_type
      when :subdomain
        subdomain = request.subdomain
        exclude_subdomains = Array(options[:exclude] || ["www"])
        
        if subdomain.present? && !exclude_subdomains.include?(subdomain)
          tenant = Tenantify.tenant_class.find_by(subdomain: subdomain)
        end
      when :header
        header_name = options[:header] || "X-Tenant-ID"
        tenant_id = request.headers[header_name]
        tenant = Tenantify.tenant_class.find_by(id: tenant_id) if tenant_id.present?
      else
        raise ArgumentError, "Unknown Tenantify resolver type: #{resolver_type}"
      end

      if tenant
        Tenantify.current_tenant = tenant
      else
        handle_tenant_not_found(options)
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
