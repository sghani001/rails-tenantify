# rails-tenantify 🏢

> Row-level multi-tenancy for Rails — scoped models, job-safe context, one database.

[![Gem Version](https://img.shields.io/gem/v/rails-tenantify.svg)](https://rubygems.org/gems/rails-tenantify)
[![Downloads](https://img.shields.io/gem/dt/rails-tenantify.svg)](https://rubygems.org/gems/rails-tenantify)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/sghani001/rails-tenantify/actions/workflows/ci.yml/badge.svg)](https://github.com/sghani001/rails-tenantify/actions/workflows/ci.yml)
![Rails](https://img.shields.io/badge/Rails-7.0%2B-red)
![Ruby](https://img.shields.io/badge/Ruby-3.1%2B-cc342d)
![Stable](https://img.shields.io/badge/stable-0.1.2-brightgreen)

**rails-tenantify** adds **row-level** multi-tenancy to Rails apps: each row belongs to a tenant via a foreign key (for example `organization_id`). One database, one migration path — unlike schema-per-tenant tools such as [apartment](https://github.com/influitive/apartment).

| RubyGems package | `rails-tenantify` |
|------------------|-------------------|
| Require in app   | `require: "rails-tenantify"` |
| Ruby module      | `Tenantify` |

---

## Table of contents

- [Compatibility](#compatibility)
- [Why rails-tenantify?](#why-rails-tenantify)
- [Installation](#installation)
- [Setup guide (step by step)](#setup-guide-step-by-step)
- [Configuration reference](#configuration-reference)
- [Models](#models)
- [Controllers & resolvers](#controllers--resolvers)
- [Setting tenant from the current user](#setting-tenant-from-the-current-user)
- [Tenant context API](#tenant-context-api)
- [Background jobs](#background-jobs)
- [Bulk-write protection](#bulk-write-protection)
- [Cross-tenant associations](#cross-tenant-associations)
- [Testing](#testing)
- [API reference](#api-reference)
- [What ships in 0.1.2](#what-ships-in-012)
- [Roadmap](#roadmap)
- [Development](#development)

---

## Compatibility

| | Version |
|---|---|
| Ruby | >= 3.1 |
| Rails | >= 7.0 (tested on 7.1) |
| Active Record | >= 7.0 |
| Database | SQLite3, PostgreSQL, MySQL |

Use **gem version >= 0.1.1** (Bundler entrypoint fix). Use **>= 0.1.2** if you run CI or deploy on Ruby 3.1.

---

## Why rails-tenantify?

| Feature | acts_as_tenant | rails-tenantify |
|---------|----------------|-----------------|
| Rails 7+ maintenance | Limited | Yes |
| Sidekiq retry + tenant | [Known issue](https://github.com/ErwinM/acts_as_tenant/issues/356) | Tenant id in job payload |
| `update_all` / `delete_all` / `destroy_all` | Unreliable | Guarded |
| Cross-tenant `belongs_to` check | Manual | Built-in |
| Unsafe `current_tenant=` | No audit | `:log`, `:raise`, `:ignore` |
| Header API tenant | DIY | `set_tenant_by :header` |
| RSpec helpers | Partial | `with_tenant` / `without_tenant` |

---

## Installation

**Gemfile**

```ruby
gem "rails-tenantify", "~> 0.1.2", require: "rails-tenantify"
```

```bash
bundle install
```

> Always use `require: "rails-tenantify"`. The gem name differs from the `tenantify` module name (same idea as `rails-persona` / `persona`).

---

## Setup guide (step by step)

### Step 1 — Configure the gem

Create `config/initializers/tenantify.rb`:

```ruby
# frozen_string_literal: true

Tenantify.configure do |config|
  config.tenant_model = "Organization"       # REQUIRED — ActiveRecord class name
  config.on_tenant_not_found = :raise       # :raise | :redirect | :null_tenant
  config.audit_overrides = :log             # :log | :raise | :ignore
end
```

| Option | Values | Default | Behavior |
|--------|--------|---------|----------|
| `tenant_model` | String class name | `nil` | Which model represents a tenant |
| `on_tenant_not_found` | `:raise` | `:raise` | If resolver finds no tenant |
| `on_tenant_not_found` | `:redirect` | | `redirect_to` fallback path |
| `on_tenant_not_found` | `:null_tenant` | | Leave `current_tenant` nil |
| `audit_overrides` | `:log` | `:log` | Warn on unsafe `current_tenant=` change |
| `audit_overrides` | `:raise` | | Raise `TenantOverrideError` |
| `audit_overrides` | `:ignore` | | Allow tenant changes |

### Step 2 — Tenant model & migration

```bash
rails g model Organization name:string subdomain:string:uniq
rails db:migrate
```

```ruby
class Organization < ApplicationRecord
  validates :name, :subdomain, presence: true
end
```

### Step 3 — Add tenant FK to scoped tables

```bash
rails g migration AddOrganizationToProjects organization:references
rails db:migrate
```

Repeat for each model that should be tenant-scoped.

### Step 4 — Scope your models

```ruby
class Project < ApplicationRecord
  include Tenantify::Scoped

  belongs_to_tenant :organization
end
```

`belongs_to_tenant`:

- adds `belongs_to :organization`
- applies a `default_scope` to the current tenant
- sets the FK on **create** from `Tenantify.current_tenant`
- validates the FK **cannot change** after create
- validates other tenant-scoped `belongs_to` rows match the same tenant

### Step 5 — Resolve tenant on requests

`Tenantify::Controller` is included automatically in Rails via the Railtie. You only need:

```ruby
class ApplicationController < ActionController::Base
  set_tenant_by :subdomain
end
```

Or for APIs:

```ruby
set_tenant_by :header, header: "X-Tenant-ID"
```

### Step 6 — Use tenant scope in the app

```ruby
# After resolver runs (or after you set current_tenant manually):
Project.all                              # scoped
Project.create!(name: "Roadmap")         # organization_id set automatically
Tenantify.current_tenant                 # => #<Organization ...>
```

### Step 7 — Jobs (optional)

No extra code for **ActiveJob** — `Tenantify::Job` is mixed in automatically. Enqueue from a request where `current_tenant` is set; `perform` restores it.

If you use **Sidekiq** directly, add `sidekiq` to your Gemfile; middleware is registered automatically when Sidekiq loads.

### Step 8 — Tests

```ruby
# spec/rails_helper.rb or spec/spec_helper.rb
RSpec.configure do |config|
  config.include Tenantify::TestHelpers

  config.before do
    Tenantify::TestHelpers.clear_tenant
  end
end
```

```ruby
with_tenant(organization) { Project.create!(name: "Demo") }
```

---

## Configuration reference

All options are set in `Tenantify.configure` (see Step 1).

---

## Models

```ruby
class Task < ApplicationRecord
  include Tenantify::Scoped
  belongs_to_tenant :organization
  belongs_to :project
end
```

| Behavior | When |
|----------|------|
| Default scope | `Tenantify.current_tenant` present and scoping enabled |
| No scope | `current_tenant` nil, or inside `Tenantify.without_tenant` |
| Auto FK on create | `organization_id` blank and `current_tenant` set |
| FK immutable | Update with changed tenant FK → validation error |

---

## Controllers & resolvers

### Subdomain

```ruby
set_tenant_by :subdomain
set_tenant_by :subdomain, exclude: %w[www admin]
set_tenant_by :subdomain, attribute: :slug   # custom column, default :subdomain
set_tenant_by :subdomain, only: [:index, :show]
```

Looks up: `Organization.find_by(subdomain: request.subdomain)` (or your `attribute`).

### Header (API)

```ruby
set_tenant_by :header
set_tenant_by :header, header: "X-Tenant-ID"
```

Looks up: `Organization.find_by(id: request.headers[header])`.

### When tenant is missing

```ruby
# config/initializers/tenantify.rb
config.on_tenant_not_found = :raise    # Tenantify::TenantNotFoundError

# or per controller:
set_tenant_by :subdomain, fallback: "/login"   # needs :redirect in config
```

### Custom resolvers

Implement `#call(request)` returning a tenant or `nil`. Use the built-in classes under `Tenantify::Resolvers` as examples.

---

## Setting tenant from the current user

If tenants map to logged-in users (no subdomain), set context in a concern:

```ruby
# app/controllers/concerns/tenantify_context.rb
module TenantifyContext
  extend ActiveSupport::Concern

  included do
    before_action :set_current_tenant_from_user
  end

  private

  def set_current_tenant_from_user
    return unless user_signed_in?

    Tenantify.current_tenant = current_user.organization
  end
end
```

```ruby
class ApplicationController < ActionController::Base
  include TenantifyContext
end
```

You can combine this with `set_tenant_by` only on specific controllers if needed.

---

## Tenant context API

```ruby
Tenantify.current_tenant          # tenant object or nil
Tenantify.current_tenant = org    # respects audit_overrides
Tenantify.current_tenant_id       # integer or nil
Tenantify.tenant_scoped?          # false inside without_tenant

Tenantify.switch_to(org) do
  Project.all                     # scoped to org
end

Tenantify.without_tenant do
  Project.unscoped.delete_all     # bypass scope + bulk guards
end

Tenantify.tenant_class            # Organization (from tenant_model)
```

`Tenantify::Switcher.switch_to` / `without_tenant` delegate to the same methods.

---

## Background jobs

### ActiveJob (built-in)

```ruby
class ExportJob < ApplicationJob
  def perform
    Tenantify.current_tenant   # restored from enqueue time
    Project.find_each { |p| p.update!(exported: true) }
  end
end
```

```ruby
Tenantify.current_tenant = current_organization
ExportJob.perform_later
```

### Sidekiq

With `sidekiq` in your Gemfile, the gem registers client/server middleware that stores `tenant_id` on the job hash and runs the job inside `Tenantify.switch_to`.

> **Not yet supported:** GoodJob, Solid Queue (planned for 0.2.0).

---

## Bulk-write protection

On models using `belongs_to_tenant`, these methods raise `Tenantify::TenantMismatchError` unless the relation is already filtered to the current tenant (or you use `without_tenant`):

- `update_all`
- `delete_all`
- `destroy_all`

```ruby
Tenantify.current_tenant = org
Project.update_all(status: "done")       # OK

Project.unscoped.update_all(status: "x") # raises

Tenantify.without_tenant do
  Project.update_all(status: "safe")     # OK
end
```

---

## Cross-tenant associations

If `Task` and `Project` are both tenant-scoped, assigning a `project` from another tenant fails validation:

```ruby
task.project = other_org_project
task.valid?  # => false
task.errors[:project]  # => ["belongs to a different tenant"]
```

---

## Testing

```ruby
RSpec.configure do |config|
  config.include Tenantify::TestHelpers
  config.before { Tenantify::TestHelpers.clear_tenant }
end
```

| Helper | Purpose |
|--------|---------|
| `with_tenant(org) { }` | Block-scoped tenant (uses `switch_to`) |
| `without_tenant { }` | Disable scoping for block |
| `Tenantify::TestHelpers.set_tenant(org)` | Set tenant (Minitest `setup`) |
| `Tenantify::TestHelpers.clear_tenant` | Reset thread-local state |

---

## API reference

### Module `Tenantify`

| Method | Description |
|--------|-------------|
| `configure { }` | Set global options |
| `configuration` | `Tenantify::Configuration` instance |
| `current_tenant` / `current_tenant=` | Thread-local tenant |
| `current_tenant_id` | Id or `nil` |
| `tenant_scoped?` | Whether scoping is active |
| `switch_to(tenant) { }` | Temporary tenant |
| `without_tenant { }` | Disable scope + bulk guards |
| `tenant_class` | Constantize `tenant_model` |

### `Tenantify::Scoped`

| Macro / method | Description |
|----------------|-------------|
| `belongs_to_tenant(name, **opts)` | Scope, FK, validations |
| `tenant_scoped?` (class) | Model uses `belongs_to_tenant` |

### `Tenantify::Controller`

| Macro | Description |
|-------|-------------|
| `set_tenant_by :subdomain, **opts` | Subdomain resolver |
| `set_tenant_by :header, **opts` | Header resolver |

Options: `exclude`, `attribute`, `header`, `fallback`, `only`, `except`, `if`, `unless`.

### Errors

| Class | When |
|-------|------|
| `Tenantify::TenantNotFoundError` | Resolver found no tenant and `on_tenant_not_found` is `:raise` |
| `Tenantify::TenantMismatchError` | Unsafe bulk write |
| `Tenantify::TenantOverrideError` | Unsafe `current_tenant=` with `audit_overrides: :raise` |
| `Tenantify::Error` | Missing `tenant_model`, etc. |

---

## What ships in 0.1.2

| Feature | Status |
|---------|--------|
| `Tenantify::Scoped` + `belongs_to_tenant` | ✅ |
| Default scope, auto FK, immutable FK | ✅ |
| Cross-tenant association validation | ✅ |
| `update_all` / `delete_all` / `destroy_all` guards | ✅ |
| `Tenantify.configure` (3 options) | ✅ |
| `set_tenant_by` `:subdomain` / `:header` | ✅ |
| `switch_to` / `without_tenant` | ✅ |
| `audit_overrides` `:log` / `:raise` / `:ignore` | ✅ |
| ActiveJob tenant serialize/restore | ✅ |
| Sidekiq middleware (if Sidekiq loaded) | ✅ |
| `Tenantify::TestHelpers` | ✅ |
| JWT / custom domain / GoodJob / Solid Queue | 🔜 roadmap |

Verified by the gem test suite (`bundle exec rspec`, 40 examples).

---

## Roadmap

| Version | Focus |
|---------|--------|
| **0.1.2** | Current — boot fix, Ruby 3.1 CI |
| **0.2.0** | GoodJob, Solid Queue |
| **0.3.0** | JWT resolver |
| **0.4.0** | Custom domains, Active Storage |
| **1.0.0** | Stable API |

See [CHANGELOG.md](CHANGELOG.md).

---

## Development

```bash
bundle _2.6.9_ install
bundle exec rspec
```

---

## Contributing

Issues and PRs: https://github.com/sghani001/rails-tenantify

## License

MIT — © Syed M. Ghani
