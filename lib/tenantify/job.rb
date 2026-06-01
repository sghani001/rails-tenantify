# frozen_string_literal: true

require "active_support/concern"

module Tenantify
  module Job
    extend ActiveSupport::Concern

    included do
      attr_accessor :tenant_id

      def serialize
        super.merge("tenant_id" => tenant_id || Tenantify.current_tenant_id)
      end

      def deserialize(job_data)
        super(job_data)
        self.tenant_id = job_data["tenant_id"]
      end

      around_perform do |_job, block|
        if tenant_id
          tenant = Tenantify.tenant_class.find_by(id: tenant_id)
          if tenant
            Tenantify.switch_to(tenant, &block)
          else
            log_missing_tenant(tenant_id)
            block.call
          end
        else
          block.call
        end
      end
    end

    private

    def log_missing_tenant(tenant_id)
      message = "[Tenantify] ActiveJob #{self.class.name} could not restore tenant #{tenant_id}"
      if defined?(Rails) && Rails.logger
        Rails.logger.warn(message)
      else
        warn(message)
      end
    end
  end
end

ActiveSupport.on_load(:active_job) do
  include Tenantify::Job
end
