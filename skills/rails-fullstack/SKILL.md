---
name: rails-fullstack
description: "Full-stack Rails patterns for HTML-first applications. Covers view components, presenters, form objects, strict locals, filter/query objects, services, concerns, callbacks, configuration, and maquina_components UI. Use when building Rails pages, forms, HTML views, ERB templates, view components, presenters, or full-stack features."
---

# Rails Full-Stack Architecture

Based on *Layered Design for Ruby on Rails Applications* by Vladimir Dementyev (Evil Martians).

## Philosophy: "The Extended Rails Way"

Extend Rails conventions with structure, not abandon them. Start simple, extract layers when complexity emerges. Think in components, not templates.

## Layered Architecture

```
Presentation:  Controllers → Form Objects → View Components → Presenters
Application:   Queries → Services → Policies → Notifications
Domain:        Models → Value Objects → Concerns (behavioral)
Infrastructure: Adapters → Serializers → Jobs → Config Objects
```

**Dependency Direction:** Upper layers depend on lower layers, never the reverse.

## Code Organization

```
app/
├── controllers/              # HTTP routing only
├── components/               # View components (Ruby + HTML + CSS + i18n)
├── forms/                    # Form objects (ActiveModel-based)
├── presenters/               # Presenters / decorators
├── queries/                  # Filter + Query objects
├── services/                 # Business operations (use sparingly)
├── policies/                 # Authorization
├── models/                   # Domain entities + rules
├── jobs/                     # Background work
└── views/                    # ERB templates (use strict locals)
```

---

## 1. View Components

Replace complex partials with self-contained Ruby objects using the `view_component` gem.

| Use View Components | Use Partials |
|--------------------|--------------|
| Design system elements (buttons, cards, modals) | Simple resource-specific templates |
| Reusable UI with conditional logic | Static HTML fragments |
| Anything needing isolated testing | Scaffolded CRUD views |

### Rules

1. **Self-contained** — Ruby class, HTML template, CSS, JS, i18n all in one folder
2. **Explicit interface** — keyword arguments define the API
3. **No global state** — no `@instance_variables` from controllers
4. **Use `before_render`** for parameter validation and i18n defaults
5. **Use Slots API** for component composition

See `reference/detailed-examples.md` for setup, code examples, and testing patterns.

---

## 2. Presenters

Extract representation logic from models. Bridge the model and view layers.

### Rules

1. **Never leak presenters to lower layers** — create them in views or pass as template locals
2. **Open presenters** (`SimpleDelegator`) for gradual adoption
3. **Closed presenters** for new UI logic (strict isolation)
4. **Multiple projections** — different presenters for different contexts (admin vs. public)
5. **Avoid HTML generation** in presenters — use view components for complex UI

See `reference/detailed-examples.md` for open/closed/multi-model presenter examples.

---

## 3. Form Objects

Handle user input submission outside of models. Presentation layer.

### Rules

1. **`#save` mimics ActiveRecord** — returns false on invalid, performs actions on valid
2. **Attributes via `.attribute`** — declares the form schema with typecasting
3. **Context via `attr_accessor`** — non-form data (current_user, etc.)
4. **Delegate model validations** — use `validate :model_is_valid` + `merge_errors!`
5. **Side effects in callbacks** — `after_commit` for emails, analytics, etc.
6. **Use for non-trivial forms** — simple CRUD can use models directly

See `reference/detailed-examples.md` for base class, single/multi/model-less form examples.

---

## 4. Strict Locals for Partials

Rails 7.1+ — enforce partial interfaces via magic comments:

```erb
<%# locals: (quiz:, result:, prev_result: nil) -%>
```

**Rule:** Never use `@instance_variables` in partials.

---

## 5. Filter Objects

Parse/validate request params for querying (presentation layer):

```ruby
module Posts
  class FeedFilter
    attr_reader :category, :query, :sort_by, :sort_dir
    ALLOWED_SORTS = %w[created_at title].freeze

    def initialize(params)
      @category = params[:category].presence
      @query = params[:q].presence
      @sort_by = ALLOWED_SORTS.include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_dir = params[:dir] == "asc" ? :asc : :desc
    end
  end
end
```

---

## 6. Query Objects

Extract complex queries from models:

```ruby
class ApplicationQuery
  private attr_reader :relation
  def initialize(relation) = @relation = relation
  def resolve(...) = relation

  class << self
    def resolve(...) = new.resolve(...)
    alias_method :call, :resolve
  end
end
```

### Rules

- **Atomic scopes** stay in models
- **Complex queries** (multi-table, CTEs, window functions) → query objects
- **Namespace under model** — `Post::WithBookmarksQuery`
- **Accept and return relations** — composable

---

## 7. Services

Use sparingly — only when operation involves multiple models or external side effects.

```ruby
class Posts::Publish < ApplicationService
  param :post, :publisher

  def call
    return failure("Already published") if post.published?
    post.transaction do
      post.update!(status: "published", published_at: Time.current)
      PostPublishedJob.perform_later(post.id)
    end
    success(post)
  end
end
```

**Don't over-extract:** Single-model logic belongs in the model.

---

## 8. Concerns

- Extract **behavior**, not code
- If removing a concern breaks most model tests → it's not a real concern
- Non-shared concerns are fine (e.g., `User::Authentication`)
- When a concern outgrows atomic behavior → promote to a separate model

```ruby
# ✅ Good: Behavior extraction
module SoftDeletable
  extend ActiveSupport::Concern
  include Discard::Model
  included do
    self.discard_column = :deleted_at
    belongs_to :deleted_by, class_name: "User", optional: true
  end
end

# ❌ Bad: Splitting by Rails DSL type
class Account < ApplicationRecord
  include Account::Associations
  include Account::Validations
end
```

---

## 9. Callbacks

| Score | Type | Action |
|-------|------|--------|
| 5/5 | Defaults/Transformers | Keep in model |
| 4/5 | Normalization, Technical (cache/counter) | Keep |
| 1-2/5 | Operations/Event handlers | Extract to form object, service, or event subscriber |

---

## 10. Configuration

Never use `ENV["X"]` directly. Use named configuration objects:

```ruby
class PaymentsConfig < ApplicationConfig
  attr_config :api_key, :webhook_secret, enabled: true
  required :api_key
  coerce_types enabled: :boolean
end
```

- Sensitive secrets → Rails credentials (per-environment)
- Non-sensitive settings → Named YAML files with defaults
- Essential secrets missing at boot → raise in initializer (fail fast)
- Never `Rails.env.production?` in business logic — use config flags

---

## 11. Maquina UI Components

For projects using `maquina_components` — ERB partials styled with Tailwind CSS 4 and data attributes (shadcn/ui-inspired).

### Core Patterns

- **Composition over configuration** — compose from small partials, don't configure via props
- **Data attributes for styling** — `data-component="card"`, `data-variant="success"`
- **Inline errors over error lists** — show errors next to fields, not in alert blocks
- **Robust input attributes** — always set `type`, `required`, `maxlength`, `autocomplete`
- **Icons via `icon_for` helper**
- **Theme via CSS variables** — `--primary`, `--secondary`, `--muted`, `--destructive`, etc.

### Component Decision Table

| Need | Component |
|------|-----------|
| Container with header/content | **Card** |
| Important message | **Alert** |
| Status indicator | **Badge** |
| Data display | **Table** |
| No data state | **Empty** |
| User actions menu | **Dropdown Menu** |
| Selection from options | **Toggle Group** / **Combobox** |
| Date selection | **Calendar** / **Date Picker** |
| Pagination | **Pagination** (Pagy) |
| Navigation | **Sidebar** / **Breadcrumbs** |
| Temporary notifications | **Toast** |
| Form inputs | `data-component="input"` on Rails helpers |

### Form Pattern

```erb
<%= form_with model: @user, data: { component: "form" } do |f| %>
  <div data-form-part="group">
    <%= f.label :email, data: { component: "label" } %>
    <%= f.email_field :email, data: { component: "input" },
        required: true, maxlength: 254, autocomplete: "email" %>
    <% if @user.errors[:email].any? %>
      <p data-form-part="error"><%= @user.errors[:email].first %></p>
    <% end %>
  </div>
  <div data-form-part="actions">
    <%= f.submit "Save", data: { component: "button", variant: "primary" } %>
  </div>
<% end %>
```

### Reference Files

For detailed component catalog, layout patterns, Turbo integration, and checklists, see:
- `reference/maquina/quickstart.md` — Quick start workflow
- `reference/maquina/component-catalog.md` — All components with props and variants
- `reference/maquina/layout-patterns.md` — Page structure, grids, responsive design
- `reference/maquina/form-patterns.md` — Forms, validation, field groups
- `reference/maquina/turbo-integration.md` — Frames, Streams, Morph with components
- `reference/maquina/spec-checklist.md` — UI implementation checklist

---

## Quick Reference

### When to Use Each Abstraction

| Abstraction | Use When | Don't Use When |
|-------------|----------|----------------|
| **View Component** | Reusable UI, design system, testable views | Simple one-off partials |
| **Presenter** | Formatting model data for display | Business logic |
| **Form Object** | Non-trivial form submission, multi-model, side effects | Simple CRUD |
| **Filter Object** | Parsing query/search params | Simple `params[:id]` |
| **Query Object** | Complex SQL, multi-table, reusable queries | Simple scopes |
| **Service** | Multi-model workflows, external side effects | Single-model logic |
| **Concern** | Atomic, self-contained behavior | Code splitting by DSL type |
| **Maquina Component** | UI with maquina_components library | Non-maquina projects |

### Controller Pattern

```ruby
class PostsController < ApplicationController
  def index
    filter = Posts::FeedFilter.new(params)
    @posts = Posts::FeedQuery.new(Post.active, filter: filter).resolve
  end

  def show
    @post = PostPresenter.new(Post.find(params[:id]))
  end

  def create
    @form = PostForm.from(params.require(:post))
    if @form.save
      redirect_to @form.post
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```
