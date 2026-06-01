# frozen_string_literal: true

module Tenantify
  module Middleware
    class SidekiqClient
      def call(_worker_class, job, _queue, _redis_pool = nil)
        job["tenant_id"] ||= Tenantify.current_tenant_id if Tenantify.current_tenant_id
        yield
      end
    end

    class SidekiqServer
      def call(_worker, job, _queue)
        tenant_id = job["tenant_id"]
        if tenant_id
          tenant = Tenantify.tenant_class.find_by(id: tenant_id)
          if tenant
            Tenantify.switch_to(tenant) { yield }
          else
            log_missing_tenant(tenant_id)
            yield
          end
        else
          yield
        end
      end

      private

      def log_missing_tenant(tenant_id)
        message = "[Tenantify] Sidekiq job could not restore tenant #{tenant_id}"
        if defined?(Rails) && Rails.logger
          Rails.logger.warn(message)
        else
          warn(message)
        end
      end
    end
  end
end
