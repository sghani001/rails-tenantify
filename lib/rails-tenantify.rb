# frozen_string_literal: true

# Bundler requires this file for the +rails-tenantify+ gem (see Gemfile + gemspec name).
# Without it, Rails may load Tenantify::Railtie alone and define an incomplete Tenantify module.
require "tenantify"
require "tenantify/railtie" if defined?(Rails::Railtie)
