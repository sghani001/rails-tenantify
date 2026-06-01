# frozen_string_literal: true

module Tenantify
  module Middleware
    class SidekiqClient
      def call(worker_class, job, queue, redis_pool = nil)
        # Inject tenant_id into the job payload if current tenant exists
        if Tenantify.current_tenant_id
          job["tenant_id"] ||= Tenantify.current_tenant_id
        end
        yield
      end
    end

    class SidekiqServer
      def call(worker, job, queue)
        tenant_id = job["tenant_id"]
        if tenant_id
          begin
            tenant = Tenantify.tenant_class.find_by(id: tenant_id)
            if tenant
              Tenantify.switch_to(tenant) do
                yield
              end
            else
              yield
            end
          rescue => e
            # Fall back safely on database issues
            yield
          end
        else
          yield
        end
      end
    end
  end
end
