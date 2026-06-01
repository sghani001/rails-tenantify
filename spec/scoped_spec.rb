# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tenantify::Scoped do
  let!(:org_a) { Organization.create!(name: "Tenant A", subdomain: "a") }
  let!(:org_b) { Organization.create!(name: "Tenant B", subdomain: "b") }

  describe "default scoping" do
    before do
      Tenantify.without_tenant do
        @proj_a = Project.create!(name: "Project A", organization: org_a)
        @proj_b = Project.create!(name: "Project B", organization: org_b)
      end
    end

    it "scopes queries to the current tenant" do
      Tenantify.current_tenant = org_a
      expect(Project.all).to contain_exactly(@proj_a)

      Tenantify.current_tenant = org_b
      expect(Project.all).to contain_exactly(@proj_b)
    end

    it "bypasses scoping when Tenantify.without_tenant is used" do
      Tenantify.current_tenant = org_a
      Tenantify.without_tenant do
        expect(Project.all).to contain_exactly(@proj_a, @proj_b)
      end
    end

    it "does not scope queries when current_tenant is nil" do
      Tenantify.current_tenant = nil
      expect(Project.all).to contain_exactly(@proj_a, @proj_b)
    end

    it "does not affect unscoped models" do
      user = User.create!(name: "Alice")
      Tenantify.current_tenant = org_a
      expect(User.all).to contain_exactly(user)
    end
  end

  describe "automatic tenant assignment" do
    it "automatically assigns the current tenant to new records" do
      Tenantify.current_tenant = org_a
      project = Project.create!(name: "Project A")
      expect(project.organization).to eq(org_a)
    end

    it "does not override explicitly assigned tenant" do
      Tenantify.current_tenant = org_a
      project = Project.create!(name: "Project B", organization: org_b)
      expect(project.organization).to eq(org_b)
    end
  end

  describe "validation: tenant cannot be changed" do
    it "adds error if tenant foreign key is changed on update" do
      Tenantify.current_tenant = org_a
      project = Project.create!(name: "Project A")
      
      Tenantify.without_tenant do
        project.organization = org_b
        expect(project).not_to be_valid
        expect(project.errors[:organization_id]).to include("cannot be changed after creation")
      end
    end
  end

  describe "cross-tenant association validation" do
    it "validates that associated scoped records belong to the same tenant" do
      Tenantify.current_tenant = org_a
      project_a = Project.create!(name: "Project A")
      task_a = Task.create!(name: "Task A", project: project_a)
      expect(task_a).to be_valid

      # Force task to org_b but project belongs to org_a
      Tenantify.without_tenant do
        task_invalid = Task.new(name: "Invalid Task", organization: org_b, project: project_a)
        expect(task_invalid).not_to be_valid
        expect(task_invalid.errors[:project]).to include("belongs to a different tenant")
      end
    end
  end

  describe "bulk write protection" do
    before do
      Tenantify.without_tenant do
        @proj_a = Project.create!(name: "Project A", organization: org_a)
      end
    end

    it "raises TenantMismatchError when update_all is called without a tenant context" do
      expect {
        Project.update_all(name: "New Name")
      }.to raise_error(Tenantify::TenantMismatchError)
    end

    it "allows update_all when tenant context is active and relation matches tenant" do
      Tenantify.current_tenant = org_a
      expect {
        Project.update_all(name: "Updated Name")
      }.not_to raise_error
      expect(@proj_a.reload.name).to eq("Updated Name")
    end

    it "raises TenantMismatchError if update_all is called on relation that bypassed tenant (e.g. unscoped)" do
      Tenantify.current_tenant = org_a
      expect {
        Project.unscoped.update_all(name: "Danger")
      }.to raise_error(Tenantify::TenantMismatchError)
    end

    it "raises TenantMismatchError when delete_all is called without a tenant context" do
      expect {
        Project.delete_all
      }.to raise_error(Tenantify::TenantMismatchError)
    end

    it "allows delete_all when tenant context is active and relation matches tenant" do
      Tenantify.current_tenant = org_a
      expect {
        Project.delete_all
      }.not_to raise_error
      expect(Project.count).to eq(0)
    end

    it "allows bulk actions when without_tenant is explicitly used" do
      Tenantify.without_tenant do
        expect {
          Project.update_all(name: "Safe")
        }.not_to raise_error
      end
    end
  end
end
