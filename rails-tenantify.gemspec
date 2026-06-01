# frozen_string_literal: true

require_relative "lib/tenantify/version"

Gem::Specification.new do |spec|
  spec.name = "rails-tenantify"
  spec.version = Tenantify::VERSION
  spec.authors = ["Syed M. Ghani"]
  spec.email = ["syedghani001@gmail.com"]

  spec.summary = "Modern multi-tenancy for Rails — row-level tenant scoping with jobs, controllers, and tests."
  spec.description = <<~DESC
    Tenantify provides row-level multi-tenancy for Rails 7+ applications: model scoping,
    controller tenant resolution, ActiveJob and Sidekiq context propagation, bulk-write
    protection, and RSpec helpers — a maintained alternative to acts_as_tenant.
  DESC

  spec.homepage = "https://github.com/sghani001/rails-tenantify"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "LICENSE",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0", "< 9"
  spec.add_dependency "activerecord", ">= 7.0", "< 9"

  spec.add_development_dependency "activejob", ">= 7.0", "< 9"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "sqlite3", ">= 1.4", "< 2"
end
