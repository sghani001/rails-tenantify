# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tenantify::Controller do
  let!(:org_a) { Organization.create!(name: "Tenant A", subdomain: "a") }
  let!(:org_b) { Organization.create!(name: "Tenant B", subdomain: "b") }

  class TestController
    attr_accessor :request, :redirected_to

    def self.before_actions
      @before_actions ||= []
    end

    def self.before_action(options = {}, &block)
      before_actions << block
    end

    include Tenantify::Controller

    def run_before_actions
      self.class.before_actions.each do |action|
        instance_eval(&action)
      end
    end

    def redirect_to(path)
      @redirected_to = path
    end
  end

  let(:request) { double("Request", subdomain: "a", headers: {}, url: "http://a.example.com/") }
  let(:controller) { TestController.new }

  before do
    TestController.before_actions.clear
    controller.request = request
  end

  describe ".set_tenant_by :subdomain" do
    before do
      TestController.set_tenant_by :subdomain
    end

    it "resolves and sets tenant by subdomain" do
      expect(Tenantify.current_tenant).to be_nil
      controller.run_before_actions
      expect(Tenantify.current_tenant).to eq(org_a)
    end

    it "raises TenantNotFoundError if tenant subdomain doesn't exist and on_tenant_not_found is :raise" do
      allow(request).to receive(:subdomain).and_return("missing")
      expect {
        controller.run_before_actions
      }.to raise_error(Tenantify::TenantNotFoundError)
    end

    it "redirects to fallback path if tenant subdomain doesn't exist and on_tenant_not_found is :redirect" do
      allow(request).to receive(:subdomain).and_return("missing")
      allow(Tenantify.configuration).to receive(:on_tenant_not_found).and_return(:redirect)
      
      # Setup controller with custom fallback
      TestController.before_actions.clear
      TestController.set_tenant_by :subdomain, fallback: "/login"
      
      controller.run_before_actions
      expect(controller.redirected_to).to eq("/login")
      expect(Tenantify.current_tenant).to be_nil
    end

    it "leaves tenant nil if on_tenant_not_found is :null_tenant" do
      allow(request).to receive(:subdomain).and_return("missing")
      allow(Tenantify.configuration).to receive(:on_tenant_not_found).and_return(:null_tenant)
      
      controller.run_before_actions
      expect(Tenantify.current_tenant).to be_nil
    end
  end

  describe ".set_tenant_by :header" do
    before do
      TestController.set_tenant_by :header
    end

    it "resolves and sets tenant by X-Tenant-ID header" do
      allow(request).to receive(:headers).and_return({ "X-Tenant-ID" => org_b.id.to_s })
      controller.run_before_actions
      expect(Tenantify.current_tenant).to eq(org_b)
    end
  end
end
