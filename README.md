# rails-tenantify 🏢

> Row-level multi-tenancy for Rails — scoped models, job-safe context, zero schema-per-tenant complexity.

[![Gem Version](https://img.shields.io/gem/v/rails-tenantify.svg)](https://rubygems.org/gems/rails-tenantify)
[![Downloads](https://img.shields.io/gem/dt/rails-tenantify.svg)](https://rubygems.org/gems/rails-tenantify)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/sghani001/rails-tenantify/actions/workflows/ci.yml/badge.svg)](https://github.com/sghani001/rails-tenantify/actions/workflows/ci.yml)
![Rails](https://img.shields.io/badge/Rails-7.0%2B-red)
![Ruby](https://img.shields.io/badge/Ruby-3.1%2B-cc342d)
![SQLite](https://img.shields.io/badge/SQLite-compatible-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-compatible-blue)
![Stable](https://img.shields.io/badge/stable-0.1.1-brightgreen)

**rails-tenantify** is a lightweight Rails gem for **row-level multi-tenancy**. Unlike [apartment](https://github.com/influitive/apartment), which switches entire databases or schemas per tenant, rails-tenantify keeps a single database and scopes records with a foreign key — the same model as [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant), but maintained for **Rails 7+**, with **retry-safe jobs**, **bulk-write guards**, and **first-class test helpers**.

The RubyGems package is [`rails-tenantify`](https://rubygems.org/gems/rails-tenantify). Require the library as `tenantify` (same pattern as `rails-persona` → `persona`).

---

## Compatibility

| | Version |
|---|---|
| Ruby | >= 3.1 |
| Rails | >= 7.0 (tested on 7.1) |
| Database | SQLite3, PostgreSQL, MySQL |

---

## Why rails-tenantify over acts_as_tenant?

| | acts_as_tenant | rails-tenantify |
|---|---|---|
| Maintenance | Stagnant / issue backlog | Actively maintained |
| Rails 7 / 8 | Partial | Full |
| Sidekiq retry loses tenant | Known issue ([#356](https://github.com/ErwinM/acts_as_tenant/issues/356)) | Tenant ID in payload + middleware |
| `update_all` / `delete_all` scoped | Unreliable | Raises unless intentionally bypassed |
| Cross-tenant association checks | Manual | Built-in validation |
| Tenant override protection | None | `:log`, `:raise`, or `:ignore` |
| API / header resolver | DIY | `set_tenant_by :header` |
| RSpec helpers | Partial | `with_tenant` / `without_tenant` |
| Test suite | Aging | RSpec, CI on Ruby 3.1–3.3 |

---

## Installation

```ruby
gem "rails-tenantify", "~> 0.1.1"
```

```bash
bundle install
```

Create `config/initializers/tenantify.rb`:

```ruby
Tenantify.configure do |config|
  config.tenant_model = "Organization"
  config.on_tenant_not_found = :raise   # :raise, :redirect, :null_tenant
  config.audit_overrides   = :log       # :log, :raise, :ignore
end
```

Add a tenant reference to scoped models (example):

```bash
rails g migration AddOrganizationToProjects organization:references
rails db:migrate
```

---

## Quick start

### 1. Define your tenant model

```ruby
class Organization < ApplicationRecord
  # e.g. subdomain: "acme" for acme.yourapp.com
end
```

### 2. Scope models to a tenant

```ruby
class Project < ApplicationRecord
  include Tenantify::Scoped

  belongs_to_tenant :organization
  has_many :tasks
end

class Task < ApplicationRecord
  include Tenantify::Scoped

  belongs_to_tenant :organization
  belongs_to :project
end
```

### 3. Resolve tenant in controllers

```ruby
class ApplicationController < ActionController::Base
  include Tenantify::Controller

  set_tenant_by :subdomain
  # set_tenant_by :header, header: "X-Tenant-ID"
end
```

### 4. Use scoped queries in the request

```ruby
# Tenantify.current_tenant is set by the controller
Project.all          # => only current organization's projects
Project.create!(name: "Q2 Roadmap")  # organization_id set automatically
```

---

## Tenant context

```ruby
Tenantify.current_tenant           # => #<Organization id: 1 ...>
Tenantify.current_tenant_id        # => 1
Tenantify.tenant_scoped?           # => true

Tenantify.switch_to(other_org) do
  Project.all                      # scoped to other_org
end
# previous tenant restored

Tenantify.without_tenant do
  Project.delete_all               # bypasses default scope + bulk guards
end
```

---

## Controller resolvers

| Resolver | Usage | Finds tenant by |
|----------|--------|-----------------|
| `:subdomain` | `set_tenant_by :subdomain` | `request.subdomain` → `Organization.find_by(subdomain: ...)` |
| `:header` | `set_tenant_by :header, header: "X-Tenant-ID"` | Header value → `Organization.find_by(id: ...)` |

Exclude reserved subdomains:

```ruby
set_tenant_by :subdomain, exclude: %w[www admin]
```

When no tenant is found, behavior is controlled by `on_tenant_not_found`:

```ruby
# :raise        → Tenantify::TenantNotFoundError
# :redirect     → redirect_to fallback path
# :null_tenant  → leave current_tenant nil
set_tenant_by :subdomain, fallback: "/login"
```

Pluggable classes live under `Tenantify::Resolvers` (`Subdomain`, `Header`).

---

## Background jobs (ActiveJob + Sidekiq)

Tenant context is **serialized when the job is enqueued** and **restored on perform** — including Sidekiq retries.

```ruby
class ReportJob < ApplicationJob
  def perform
    Tenantify.current_tenant   # same org as when the job was enqueued
    Project.find_each { |p| p.update!(status: "exported") }
  end
end

# In a request:
Tenantify.current_tenant = current_organization
ReportJob.perform_later
```

For native Sidekiq workers (non–ActiveJob), middleware injects `tenant_id` into the job hash and wraps execution in `Tenantify.switch_to`.

---

## Bulk-write protection

`update_all`, `delete_all`, and `destroy_all` on tenant-scoped models raise `Tenantify::TenantMismatchError` unless the relation is already limited to the current tenant:

```ruby
Tenantify.current_tenant = org
Project.update_all(status: "archived")   # OK — scoped to org

Project.unscoped.update_all(status: "x") # raises TenantMismatchError

Tenantify.without_tenant do
  Project.update_all(status: "migrated") # OK — intentional bypass
end
```

---

## Cross-tenant association validation

```ruby
Tenantify.current_tenant = org_a
project_a = Project.create!(name: "Alpha")

task = Task.new(name: "Bad", organization: org_b, project: project_a)
task.valid?   # => false
task.errors[:project]  # => ["belongs to a different tenant"]
```

---

## Tenant override auditing

```ruby
Tenantify.configure { |c| c.audit_overrides = :raise }

Tenantify.current_tenant = org_a
Tenantify.current_tenant = org_b
# => Tenantify::TenantOverrideError
```

Use `:log` to warn via `Rails.logger` without raising.

---

## Test helpers (RSpec / Minitest)

```ruby
RSpec.configure do |config|
  config.include Tenantify::TestHelpers
end

it "creates under a tenant" do
  with_tenant(org_a) do
    project = Project.create!(name: "Demo")
    expect(project.organization_id).to eq(org_a.id)
  end
end

without_tenant do
  Project.delete_all
end

# Minitest
setup    { Tenantify::TestHelpers.set_tenant(org_a) }
teardown { Tenantify::TestHelpers.clear_tenant }
```

---

## Configuration

```ruby
# config/initializers/tenantify.rb
Tenantify.configure do |config|
  config.tenant_model          = "Organization"  # required
  config.on_tenant_not_found   = :raise            # :raise, :redirect, :null_tenant
  config.audit_overrides       = :log              # :log, :raise, :ignore
end
```

---

## Comparison with other approaches

| Approach | How it works | rails-tenantify advantage |
|----------|----------------|---------------------------|
| **acts_as_tenant** | Row-level FK scope | Modern Rails, jobs, bulk guards, maintained |
| **apartment** | Schema / DB per tenant | Simpler ops — one DB, one migration path |
| **acts_as_subtenant** | Nested tenants | Flat, explicit `belongs_to_tenant` |
| **Custom `default_scope`** | Hand-rolled | Override protection, jobs, tests included |

---

## API reference

| Method / macro | Description |
|----------------|-------------|
| `Tenantify.configure` | Global configuration block |
| `Tenantify.current_tenant` | Current tenant object (thread-local) |
| `Tenantify.current_tenant=` | Set tenant (respects `audit_overrides`) |
| `Tenantify.current_tenant_id` | Current tenant id or `nil` |
| `Tenantify.tenant_scoped?` | Whether default scope is active |
| `Tenantify.tenant_class` | Constantized `tenant_model` class |
| `Tenantify.switch_to(tenant) { }` | Temporary tenant switch |
| `Tenantify.without_tenant { }` | Disable scoping and bulk guards |
| `include Tenantify::Scoped` | Model concern for row-level scope |
| `belongs_to_tenant :association` | FK macro + validations + default scope |
| `include Tenantify::Controller` | Controller concern |
| `set_tenant_by :subdomain` | Subdomain resolver |
| `set_tenant_by :header` | Header resolver |
| `Tenantify::Job` | ActiveJob tenant serialize / restore (auto-included) |
| `with_tenant(tenant) { }` | Test helper — block switch |
| `without_tenant { }` | Test helper — disable scope |
| `Tenantify::TestHelpers.clear_tenant` | Reset thread-local state |

### Errors

| Error | When |
|-------|------|
| `Tenantify::TenantNotFoundError` | Resolver cannot find a tenant |
| `Tenantify::TenantMismatchError` | Unsafe bulk write without tenant scope |
| `Tenantify::TenantOverrideError` | Unsafe `current_tenant=` when `audit_overrides` is `:raise` |
| `Tenantify::Error` | Base error (e.g. missing `tenant_model`) |

---

## Roadmap

| Version | Focus |
|---------|--------|
| **0.1.0** | Core scoping, subdomain/header resolvers, ActiveJob, Sidekiq, test helpers |
| **0.2.0** | GoodJob, Solid Queue |
| **0.3.0** | JWT resolver, API improvements |
| **0.4.0** | Custom domains, Active Storage |
| **0.6.0** | Hotwire / Turbo, GraphQL context |
| **1.0.0** | Stable API, full documentation |

See [CHANGELOG.md](CHANGELOG.md) for release notes.

---

## Development

```bash
bundle install
bundle exec rspec
```

---

## Contributing

Bug reports and pull requests are welcome at https://github.com/sghani001/rails-tenantify.

## License

MIT — © Syed M. Ghani
