# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tenantify::TestHelpers do
  include described_class

  let!(:org_a) { Organization.create!(name: "Tenant A", subdomain: "a") }
  let!(:org_b) { Organization.create!(name: "Tenant B", subdomain: "b") }

  describe "#with_tenant" do
    it "sets the tenant for the block and restores afterward" do
      Tenantify.current_tenant = org_a

      with_tenant(org_b) do
        expect(Tenantify.current_tenant).to eq(org_b)
      end

      expect(Tenantify.current_tenant).to eq(org_a)
    end
  end

  describe "#without_tenant" do
    it "disables tenant scoping for the block" do
      expect(Tenantify.tenant_scoped?).to be(true)

      without_tenant do
        expect(Tenantify.tenant_scoped?).to be(false)
      end

      expect(Tenantify.tenant_scoped?).to be(true)
    end
  end

  describe ".clear_tenant" do
    it "resets thread-local tenant state" do
      Tenantify.current_tenant = org_a
      described_class.clear_tenant
      expect(Tenantify.current_tenant).to be_nil
    end
  end
end
