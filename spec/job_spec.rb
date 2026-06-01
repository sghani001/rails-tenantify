# frozen_string_literal: true

require "spec_helper"
require "tenantify/middleware/sidekiq"

RSpec.describe "Job and Sidekiq Multi-Tenancy" do
  let!(:org) { Organization.create!(name: "Job Tenant", subdomain: "job") }

  describe Tenantify::Job do
    class TestJob < ActiveJob::Base
      def perform
        $last_executed_tenant = Tenantify.current_tenant
      end
    end

    before do
      $last_executed_tenant = nil
    end

    it "serializes the tenant ID on enqueue and restores it during perform" do
      Tenantify.current_tenant = org
      
      # Enqueue and perform job inline
      TestJob.perform_later
      
      expect($last_executed_tenant).to eq(org)
    end

    it "does not crash if enqueued without a tenant context" do
      Tenantify.current_tenant = nil
      
      TestJob.perform_later
      
      expect($last_executed_tenant).to be_nil
    end
  end

  describe Tenantify::Middleware do
    let(:client_middleware) { Tenantify::Middleware::SidekiqClient.new }
    let(:server_middleware) { Tenantify::Middleware::SidekiqServer.new }

    describe "SidekiqClient" do
      it "injects the current tenant ID into the job payload" do
        Tenantify.current_tenant = org
        job_payload = {}
        
        client_middleware.call(double("Worker"), job_payload, "default") do
          # execution
        end
        
        expect(job_payload["tenant_id"]).to eq(org.id)
      end

      it "does not inject anything if current tenant is nil" do
        Tenantify.current_tenant = nil
        job_payload = {}
        
        client_middleware.call(double("Worker"), job_payload, "default") do
          # execution
        end
        
        expect(job_payload.key?("tenant_id")).to be(false)
      end
    end

    describe "SidekiqServer" do
      it "restores the tenant context and wraps execution in Tenantify.switch_to" do
        job_payload = { "tenant_id" => org.id }
        
        $executed_with_tenant = nil
        
        server_middleware.call(double("Worker"), job_payload, "default") do
          $executed_with_tenant = Tenantify.current_tenant
        end
        
        expect($executed_with_tenant).to eq(org)
        expect(Tenantify.current_tenant).to be_nil
      end

      it "executes normally and leaves tenant nil if tenant_id is missing" do
        job_payload = {}
        $executed = false
        
        server_middleware.call(double("Worker"), job_payload, "default") do
          $executed = true
        end
        
        expect($executed).to be(true)
        expect(Tenantify.current_tenant).to be_nil
      end
    end
  end
end
