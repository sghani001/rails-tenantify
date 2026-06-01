# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2] - 2026-06-01

### Fixed

- Pin `connection_pool` to `< 3` and `minitest` to `< 6` in the Gemfile so Ruby 3.1 CI can run (both require Ruby >= 3.2 at latest major versions)

## [0.1.1] - 2026-06-01

### Fixed

- Add `lib/rails-tenantify.rb` so Bundler/Rails load the full gem API ([#1](https://github.com/sghani001/rails-tenantify/issues/1))
- Guard `Tenantify::Railtie` so it always requires `tenantify` first — fixes `undefined method 'configure' for Tenantify:Module` in Rails initializers

## [0.1.0] - 2026-06-01

Published as **`rails-tenantify`** on RubyGems (`gem "rails-tenantify"`). The name `tenantify` is already used by an unrelated gem from 2016.

### Added

- `Tenantify::Scoped` model concern with `belongs_to_tenant` macro and default scope
- Automatic tenant assignment on create and immutability validation on update
- Cross-tenant `belongs_to` association validation
- Bulk-write protection for `update_all`, `delete_all`, and `destroy_all`
- `Tenantify::Controller` with `set_tenant_by` for `:subdomain` and `:header` resolvers
- Pluggable resolvers under `Tenantify::Resolvers`
- Thread-local `Tenantify.current_tenant` via `ActiveSupport::CurrentAttributes`
- `Tenantify.switch_to` and `Tenantify.without_tenant` block helpers
- Tenant override auditing (`:log`, `:raise`, or `:ignore`)
- `Tenantify::Job` concern for ActiveJob tenant serialization and restoration
- Sidekiq client/server middleware for native Sidekiq workers
- `Tenantify::TestHelpers` for RSpec and Minitest
- Configuration DSL via `Tenantify.configure`
