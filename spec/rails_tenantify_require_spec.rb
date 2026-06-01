# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rails-tenantify entrypoint" do
  it "exposes Tenantify.configure after the gem is loaded" do
    expect(Tenantify).to respond_to(:configure)
    expect(Tenantify).to respond_to(:current_tenant)
    expect(Tenantify::Scoped).to be_a(Module)
  end

  it "ships lib/rails-tenantify.rb for Bundler autoload" do
    path = File.expand_path("../lib/rails-tenantify.rb", __dir__)
    expect(File).to exist(path)
  end
end
