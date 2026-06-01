# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "active_job"
require "tenantify"

# Set up in-memory SQLite database for testing
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Define Schema
ActiveRecord::Schema.define do
  create_table :organizations, force: true do |t|
    t.string :name
    t.string :subdomain
    t.timestamps
  end

  create_table :projects, force: true do |t|
    t.integer :organization_id
    t.string :name
    t.timestamps
  end

  create_table :tasks, force: true do |t|
    t.integer :organization_id
    t.integer :project_id
    t.string :name
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end
end

# Define Models
class Organization < ActiveRecord::Base
  # Dummy model representing tenant
end

class User < ActiveRecord::Base
  # Unscoped model
end

class Project < ActiveRecord::Base
  include Tenantify::Scoped
  belongs_to_tenant :organization
  has_many :tasks
end

class Task < ActiveRecord::Base
  include Tenantify::Scoped
  belongs_to_tenant :organization
  belongs_to :project
end

# Configure ActiveJob for inline execution in tests
ActiveJob::Base.queue_adapter = :inline
ActiveJob::Base.logger = Logger.new(nil)

# Configure Tenantify
Tenantify.configure do |config|
  config.tenant_model = "Organization"
  config.on_tenant_not_found = :raise
  config.audit_overrides = :log
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean database and Tenantify between tests
  config.before(:each) do
    Tenantify.without_tenant do
      Organization.delete_all
      Project.delete_all
      Task.delete_all
      User.delete_all
    end

    Tenantify::TestHelpers.clear_tenant
  end
end
