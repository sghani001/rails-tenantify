# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tenantify do
  let!(:org_a) { Organization.create!(name: "Tenant A", subdomain: "a") }
  let!(:org_b) { Organization.create!(name: "Tenant B", subdomain: "b") }

  describe ".current_tenant" do
    it "can get and set the current tenant" do
      expect(Tenantify.current_tenant).to be_nil
      
      Tenantify.current_tenant = org_a
      expect(Tenantify.current_tenant).to eq(org_a)
      expect(Tenantify.current_tenant_id).to eq(org_a.id)
    end

    it "raises TenantOverrideError if unsafe override is attempted and config is set to :raise" do
      Tenantify.current_tenant = org_a
      
      allow(Tenantify.configuration).to receive(:audit_overrides).and_return(:raise)
      
      expect {
        Tenantify.current_tenant = org_b
      }.to raise_error(Tenantify::TenantOverrideError)
    end

    it "does not raise if setting same tenant again" do
      Tenantify.current_tenant = org_a
      allow(Tenantify.configuration).to receive(:audit_overrides).and_return(:raise)
      
      expect {
        Tenantify.current_tenant = org_a
      }.not_to raise_error
    end
  end

  describe ".switch_to" do
    it "temporarily changes the tenant inside the block and restores it after" do
      Tenantify.current_tenant = org_a
      
      Tenantify.switch_to(org_b) do
        expect(Tenantify.current_tenant).to eq(org_b)
      end
      
      expect(Tenantify.current_tenant).to eq(org_a)
    end
  end

  describe ".without_tenant" do
    it "disables tenant scoping inside the block" do
      expect(Tenantify.tenant_scoped?).to be(true)
      
      Tenantify.without_tenant do
        expect(Tenantify.tenant_scoped?).to be(false)
      end
      
      expect(Tenantify.tenant_scoped?).to be(true)
    end
  end

  describe ".tenant_class" do
    it "returns the Organization class based on config" do
      expect(Tenantify.tenant_class).to eq(Organization)
    end

    it "raises an error if config is empty" do
      allow(Tenantify.configuration).to receive(:tenant_model).and_return(nil)
      expect {
        Tenantify.tenant_class
      }.to raise_error(Tenantify::Error)
    end
  end
end
