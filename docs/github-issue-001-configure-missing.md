# GitHub issue #1 (copy/paste)

**Title:** `Tenantify.configure` undefined when gem is named `rails-tenantify`

**Labels:** `bug`

## Describe the bug

In a Rails 7 app with:

```ruby
gem "rails-tenantify"
```

and `config/initializers/tenantify.rb`:

```ruby
Tenantify.configure do |config|
  config.tenant_model = "Organization"
end
```

boot fails with:

```text
NoMethodError: undefined method `configure' for Tenantify:Module
```

## Root cause

Rails can load `lib/tenantify/railtie.rb` before `lib/tenantify.rb`. That defines `module Tenantify` with only `Tenantify::Railtie`, so `configure` and the rest of the API are never loaded.

The published gem name is `rails-tenantify`, but there was no `lib/rails-tenantify.rb` entrypoint for Bundler.

## Expected behavior

`Tenantify.configure` is available after `Bundler.require` / Rails boot.

## Fix (0.1.1)

- Add `lib/rails-tenantify.rb` requiring `tenantify` and the railtie
- Require `tenantify` at the top of `lib/tenantify/railtie.rb` when `configure` is missing
- Use `gem "rails-tenantify", require: "rails-tenantify"` in the host app Gemfile

## Environment

- rails-tenantify: 0.1.0
- Ruby: 3.2.5
- Rails: 7.0.8
