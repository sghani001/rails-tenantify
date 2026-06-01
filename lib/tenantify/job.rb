# frozen_string_literal: true

require "active_support/concern"

module Tenantify
  module Job
    extend ActiveSupport::Concern

    included do
      attr_accessor :tenant_id

      # Serialize the current tenant ID into the job payload
      def serialize
        super.merge("tenant_id" => tenant_id || Tenantify.current_tenant_id)
      end

      # Deserialize the tenant ID back from the job payload
      def deserialize(job_data)
        super(job_data)
        self.tenant_id = job_data["tenant_id"]
      end

      # Automatically wrap job execution inside the correct tenant context
      around_perform do |_job, block|
        if tenant_id
          begin
            tenant = Tenantify.tenant_class.find_by(id: tenant_id)
            if tenant
              Tenantify.switch_to(tenant, &block)
            else
              block.call
            end
          rescue => e
            # Fall back safely if database is unavailable or lookup fails
            block.call
          end
        else
          block.call
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_job) do
  include Tenantify::Job
end
