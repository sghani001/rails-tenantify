# rails-tenantify

**Modern multi‑tenancy for Rails 7+ / Ruby 3.1+**

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Model Scoping](#model-scoping)
  - [Controller Tenant Resolution](#controller-tenant-resolution)
  - [Background Jobs](#background-jobs)
  - [Test Helpers](#test-helpers)
- [Bulk‑Write Protection](#bulk-write-protection)
- [Error Handling](#error-handling)
- [Development & Testing](#development--testing)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Row‑level tenant scoping** via `Tenantify::Scoped` – automatic `default_scope` based on the current tenant.
- **Tenant assignment** – `belongs_to_tenant` macro sets the foreign key on create and validates immutability.
- **Cross‑tenant association validation** – prevents associations that belong to a different tenant.
- **Controller helpers** – `set_tenant_by` macro supports subdomain and header resolution out of the box.
- **Background job integration** – works with Sidekiq, GoodJob, Solid Queue and any ActiveJob adapter. Tenant context is serialized and restored for each job execution.
- **Bulk‑write protection** – `update_all`, `delete_all`, and `destroy_all` raise `Tenantify::TenantMismatchError` unless explicitly disabled with `Tenantify.without_tenant`.
- **Test helpers** – simple RSpec/Minitest DSL (`with_tenant`, `without_tenant`, `clear_tenant`).
- **Full Ruby 3.1+ / Rails 7+ compatibility** – no deprecated APIs.

---

## Installation

Add the gem to your `Gemfile`:

```ruby
# Gemfile
gem "tenantify", git: "https://github.com/YOUR_USER/rails-tenantify.git"
```

Then run:

```bash
bundle install
```

---

## Configuration

Create an initializer, e.g. `config/initializers/tenantify.rb`:

```ruby
Tenantify.configure do |config|
  config.tenant_model = "Organization"   # model that represents a tenant
  config.on_tenant_not_found = :raise   # :raise, :redirect, or :null_tenant
  config.audit_overrides   = :log      # :log, :raise, or :ignore
end
```

* `tenant_model` – name of the ActiveRecord model that stores tenant data.
* `on_tenant_not_found` – how the system reacts when a tenant cannot be resolved.
* `audit_overrides` – what to do when code attempts to override the current tenant unsafely.

---

## Usage

### Model Scoping

```ruby
class Project < ApplicationRecord
  include Tenantify::Scoped
  belongs_to_tenant :organization
  has_many :tasks
end
```

* `belongs_to_tenant :organization` adds a `organization_id` foreign key, sets it automatically from `Tenantify.current_tenant`, and validates that it never changes after creation.
* A `default_scope` filters all queries to the current tenant unless `Tenantify.without_tenant` is used.

### Controller Tenant Resolution

```ruby
class ApplicationController < ActionController::Base
  include Tenantify::Controller
  set_tenant_by :subdomain   # or :header, :param, custom resolver
end
```

* Subdomain resolver extracts the subdomain from the request host, looks up the tenant model, and sets `Tenantify.current_tenant`.
* You can define custom resolvers by implementing a class with `#call(request)` that returns a tenant instance or raises `Tenantify::TenantNotFoundError`.

### Background Jobs

```ruby
class ExampleJob < ApplicationJob
  queue_as :default

  def perform(record_id)
    record = Project.find(record_id)
    # Tenant context is automatically restored here
    record.update!(name: "Updated")
  end
end
```

* When the job is enqueued, the current tenant ID is stored in the payload.
* On execution, the job wrapper restores the tenant via `Tenantify.switch_to`.
* For native Sidekiq workers (non‑ActiveJob) the middleware in `Tenantify::Middleware::Sidekiq` does the same.

### Test Helpers

```ruby
RSpec.configure do |config|
  config.include Tenantify::TestHelpers
end
```

```ruby
it "creates a record under a tenant" do
  with_tenant(org_a) do
    project = Project.create!(name: "Demo")
    expect(project.organization_id).to eq(org_a.id)
  end
end
```

* `with_tenant(tenant) { … }` temporarily switches to the supplied tenant.
* `without_tenant { … }` disables scoping for bulk operations.
* `Tenantify::TestHelpers.clear_tenant` resets the thread‑local state between examples (already called in `spec_helper.rb`).

---

## Bulk‑Write Protection

Any call to `update_all`, `delete_all`, or `destroy_all` on a tenant‑scoped model will raise `Tenantify::TenantMismatchError` unless you explicitly wrap the call in:

```ruby
Tenantify.without_tenant do
  Project.delete_all   # allowed – bypasses tenant checks
end
```

This guard prevents accidental cross‑tenant data loss.

---

## Error Handling

| Error class | When raised |
|------------|--------------|
| `Tenantify::TenantMismatchError` | Bulk write attempted without a proper tenant scope. |
| `Tenantify::TenantOverrideError` | Code tries to override the current tenant when `audit_overrides` is set to `:raise`. |
| `Tenantify::TenantNotFoundError` | Resolver cannot find a matching tenant. |
| `Tenantify::Error` (base) | Generic gem errors. |

---

## Development & Testing

```bash
# Install development dependencies
bundle install

# Run the full test suite
bundle exec rspec
```

The test suite lives in `spec/` and includes:
* Model scoping specifications
* Controller tenant resolution specs
* Background‑job serialization specs
* Switcher (`with_tenant`, `without_tenant`) specs

Continuous integration can be set up with GitHub Actions – a minimal workflow is provided in `.github/workflows/ci.yml`.

---

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/awesome‑feature`).
3. Write tests for your changes.
4. Ensure the entire suite passes (`bundle exec rspec`).
5. Open a Pull Request with a clear description of the change.

Please adhere to the existing code style (RuboCop recommendations) and keep the documentation up to date.

---

## License

`rails-tenantify` is released under the MIT License – see the `LICENSE` file for details.
