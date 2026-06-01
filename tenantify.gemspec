# frozen_string_literal: true

require_relative "lib/tenantify/version"

Gem::Specification.new do |spec|
  spec.name = "tenantify"
  spec.version = Tenantify::VERSION
  spec.authors = ["HP"]
  spec.email = ["support@tenantify.org"]
  spec.summary = "Modern multi-tenancy for Rails, solving every real-world problem acts_as_tenant couldn't."
  spec.description = "A powerful, modern row-level multi-tenancy gem for Rails 7.0+ / Ruby 3.1+ supporting Sidekiq, GoodJob, and Solid Queue."
  spec.homepage = "https://github.com/rails-gems/rails-tenantify"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "LICENSE", "README.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"

  # We use add_development_dependency for test tools
  # Using older standard gemspec pattern or Bundler groups
end
