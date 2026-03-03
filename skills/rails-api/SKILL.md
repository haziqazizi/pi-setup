---
name: rails-api
description: "Rails API development patterns for production applications. Covers layered architecture (Filter → Query → Resource), SQL JSON aggregation, Alba serialization, policies, notifications, configuration, concerns heuristics, async-first with Falcon, and ActiveRecord performance. Use when writing Rails API code, creating controllers, queries, services, policies, or serializers."
---

# Rails API Architecture

## Philosophy: "The Extended Rails Way"

Extend Rails conventions with structure, not abandon them. Start simple, extract layers when complexity emerges.

## Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  Controllers (HTTP routing) → Filters (param parsing)           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                            │
│  Queries → Services → Policies → Notifications                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       DOMAIN LAYER                               │
│  Models (entities + rules) → Value Objects → Domain Services    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                          │
│  Adapters (external APIs) → Resources (serialization) → Jobs    │
└─────────────────────────────────────────────────────────────────┘
```

**Dependency Direction:** Never violate! Infrastructure → Domain is the most common violation.

## Code Organization

```
app/
├── controllers/api/v2/      # HTTP routing only
├── queries/                  # Filters + Query objects
│   ├── {resource}/
│   │   ├── {resource}_filter.rb
│   │   └── {resource}_query.rb
│   └── application_query.rb
├── services/                 # Business operations (use sparingly)
├── policies/                 # Authorization rules (per-resource)
├── deliveries/               # Notification orchestration (multi-channel)
├── adapters/                 # External APIs
├── resources/                # Alba serializers
├── config/                   # Named configuration objects
└── jobs/                     # Background work
```

---

## Layer Responsibilities

### 1. Presentation Layer

**Controllers**: HTTP routing and response handling ONLY.

```ruby
class Api::V2::ItemsController < Api::BaseController
  def index
    filter = Items::IndexFilter.new(
      params.permit(:category, :include, :limit, :cursor),
      user_id: current_user_id
    )

    result = Items::IndexQuery.new(Item.active, filter: filter).call

    serialized = result[:data].map do |item|
      ItemResource.new(item, params: filter.serialization_params).serializable_hash
    end

    render json: { data: serialized, meta: result[:meta] }
  end
end
```

**Filters**: User input validation and transformation (`app/queries/*/`).

```ruby
module Items
  class IndexFilter
    attr_reader :category, :cursor, :limit, :includes

    ALLOWED_INCLUDES = %w[assets seller].freeze
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100

    def initialize(params, user_id: nil)
      @category = params[:category].presence
      @user_id = user_id
      @cursor = params[:cursor].presence
      @limit = parse_limit(params[:limit])
      @includes = parse_includes(params[:include])
    end

    def authenticated?
      @user_id.present?
    end

    def include?(key)
      includes.include?(key)
    end

    def serialization_params
      {
        include_assets: include?("assets"),
        include_seller: include?("seller"),
        user_id: @user_id
      }
    end

    private

    def parse_limit(limit_param)
      [[limit_param.to_i, DEFAULT_LIMIT].max, MAX_LIMIT].min
    end

    def parse_includes(include_param)
      raw = include_param.to_s.split(",").map(&:strip)
      raw.select { |i| ALLOWED_INCLUDES.include?(i) }.to_set
    end
  end
end
```

### 2. Application Layer

**Queries**: Data retrieval with SQL JSON aggregation.

⚠️ **MANDATORY: Use PostgreSQL `json_build_object` / `json_agg` for related data - NO Ruby loops, NO N+1 preloads**

```ruby
module Items
  class IndexQuery < ApplicationQuery
    attr_reader :filter

    def initialize(relation = Item.active, filter:)
      super(relation)
      @filter = filter
    end

    def call
      rel = apply_filters(relation)
      rel = apply_sql_enrichments(rel)
      paginate(rel)
    end

    private

    def apply_filters(rel)
      rel = rel.where(category: filter.category) if filter.category.present?
      rel
    end

    def apply_sql_enrichments(rel)
      rel.select("items.*", *enrichment_columns)
    end

    def enrichment_columns
      columns = []
      columns << seller_json_sql if filter.include?("seller")
      columns << assets_json_sql if filter.include?("assets")
      columns
    end
  end
end
```

**Services**: Use when operation involves multiple models or external side effects.

```ruby
class Items::Publish < ApplicationService
  param :item
  param :publisher

  def call
    return failure("Already published") if item.published?

    item.transaction do
      item.update!(status: 'published', published_at: Time.current)
      notify_subscribers
    end

    success(item)
  end

  private

  def notify_subscribers
    ItemPublishedJob.perform_later(item.id)
  end
end
```

**Policies**: Authorization rules live in the Application layer. Enforcement happens in Presentation (controllers).

```ruby
class ItemPolicy < ApplicationPolicy
  def publish?
    permission?(:manage_all_items) || (
      permission?(:manage_items) && item.seller_id == user.id
    )
  end

  relation_scope(:manageable) do |scope|
    next scope.all if permission?(:manage_all_items)
    next scope.where(seller_id: user.id) if permission?(:manage_items)
    scope.none
  end
end
```

Controllers enforce with a single call — policy class and rule are inferred:
```ruby
def destroy
  item = Item.find(params[:id])
  authorize! item
  item.destroy!
  render json: { success: true }
end
```

**Rules:**
- Check **permissions**, not roles (`permission?(:manage_items)`, never `user.admin?`)
- Models live in an **already-authorized context** — no `#can?` methods on domain objects
- Unit-test policies in isolation; at controller level, just verify authorization was performed
- Use **relation scopes** on policies to filter collections (avoids N+1 authorization checks)

**Notifications**: When multiple channels exist (email, SMS, push, in-app), extract a dedicated notification layer. Never let notification logic bloat services or model callbacks.

```ruby
class ItemDelivery < ApplicationDelivery
  delivers :published

  before_notify :ensure_enabled
  before_notify :ensure_mailer_enabled, on: :mailer
end
```

**Rules:**
- Mailers/notifiers sit in Application layer — never invoke from model callbacks (layer violation)
- Each channel is a **plugin** responsible for checking user preferences
- Notification preferences belong in a **value object** or separate table, not as columns on User
- Service objects delegate to the delivery class: `ItemDelivery.with(user:).published(item).deliver_later`

### 3. Domain Layer

**Models**: Domain entities and rules ONLY.

```ruby
class Item < ApplicationRecord
  belongs_to :seller
  has_many :assets, dependent: :destroy

  validates :title, presence: true

  def published?
    status == 'published'
  end

  scope :active, -> { where(is_deleted: false) }

  # NO business workflows here!
  # NO authorization logic!
  # NO presentation formatting!
end
```

### 4. Infrastructure Layer

**Resources (Alba)**: Read directly from SQL JSON columns. NEVER preload. NEVER iterate associations.

```ruby
class ItemResource
  include Alba::Resource

  attributes :id, :title, :status

  attribute :seller do |item|
    item.try(:seller_json)
  end

  attribute :assets do |item|
    item.try(:assets_json)
  end

  attribute :is_favorited do |item|
    params[:include_user_context] ? (item.try(:user_favorited) || false) : false
  end
end
```

**Alba Params Rule (CRITICAL)**: Use `params` METHOD in attribute blocks, NOT the block parameter.
```ruby
# ❌ WRONG — second param is nil
attribute :x do |obj, p|
  p[:key]
end

# ✅ CORRECT — use the params method
attribute :x do |obj|
  params[:key]
end

# ✅ NESTED — pass params explicitly
attribute :seller do |item|
  SellerResource.new(item.seller, params: params).serializable_hash
end
```

---

## SQL JSON Aggregation Patterns

### Pattern 1: Single related object → `json_build_object`
```ruby
def seller_json_sql
  <<~SQL.squish
    (
      SELECT json_build_object(
        'id', s.id,
        'name', s.name,
        'avatar_url', s.avatar_url
      )
      FROM sellers s
      WHERE s.id = items.seller_id
    ) AS seller_json
  SQL
end
```

### Pattern 2: Collection → `json_agg` with `COALESCE`
```ruby
def assets_json_sql
  <<~SQL.squish
    (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id', a.id,
          'url', a.url,
          'asset_type', a.asset_type
        ) ORDER BY a.position
      ), '[]'::json)
      FROM assets a
      WHERE a.item_id = items.id
        AND a.is_deleted = false
    ) AS assets_json
  SQL
end
```

### Pattern 3: Boolean flags → `EXISTS`
```ruby
def user_favorited_sql
  <<~SQL.squish
    EXISTS(
      SELECT 1 FROM favorites
      WHERE favorites.item_id = items.id
        AND favorites.user_id = #{quoted_user_id}
    ) AS user_favorited
  SQL
end
```

### Pattern 4: Aggregates → scalar subquery
```ruby
def comment_count_sql
  <<~SQL.squish
    (
      SELECT COUNT(*)
      FROM comments
      WHERE comments.item_id = items.id
    ) AS comment_count
  SQL
end
```

### Query Object Rules

| Rule | Correct | Wrong |
|------|---------|-------|
| Related objects | `json_build_object(...)` subquery | `includes(:assoc)` then iterate |
| Collections | `COALESCE(json_agg(...), '[]'::json)` | `.map { \|x\| ... }` in Ruby |
| Boolean flags | `EXISTS(...)` subquery | `.any?` in Ruby |
| Counts | `(SELECT COUNT(*) ...)` | `.count` in Ruby |
| Empty arrays | `COALESCE(..., '[]'::json)` | Risk of `null` |

---

## When to Use Each Pattern

| Pattern | Use When | Avoid When |
|---------|----------|------------|
| **Filter** | Parsing/validating request params | Simple param access |
| **Query** | Complex queries, SQL enrichments, pagination | Simple model scopes |
| **Service** | Multi-model workflows, external side effects | Single model logic |
| **Policy** | Authorization rules | Resource filtering |

## Common Misconceptions

#### ❌ "Service Objects for All Business Logic"
Services coordinate multiple objects. Don't extract logic that belongs in a single model.

#### ❌ "All Models Must Be Thin"
Models should be complex if the domain is complex. Goal is appropriate complexity.

#### ❌ "All Callbacks Are Evil"
Callbacks are fine for model-level normalizations (e.g., `before_validation :normalize_title`). Bad for business operations (e.g., `after_create :send_notifications`).

**Callback scoring** (keep in model → extract):

| Score | Type | Example | Action |
|-------|------|---------|--------|
| 5/5 | Transformers/defaults | `before_validation :compute_shortname` | Keep |
| 4/5 | Normalization | `before_validation :squish_content` | Keep (use `.normalizes` in Rails 7.1+) |
| 4/5 | Technical/utility | `counter_cache`, `touch` | Keep |
| 1-2/5 | Operations/event handlers | `after_commit :send_email`, `:sync_crm` | Extract to service or delivery |

#### ❌ "Concerns Are Free Decomposition"
Concerns should extract **behavior**, not code. If removing a concern breaks most model tests, it's just split code — not a real concern.

| Good Concern | Bad Concern |
|-------------|-------------|
| `SoftDeletable` — self-contained feature | `Account::Associations` — splits by Rails DSL type |
| `has_secure_password` — atomic behavior | `Account::Validations` — no real encapsulation |

**When to extract further:** If a concern grows complex or needs private state, promote it to a **delegate object** (`has_one` + `delegate`) or a **value object** (`Data.define`).

---

## Async-First with Falcon

If running on Falcon (fiber-based async web server), all request-path code must be async-aware.

**Core Principles:**
1. Assume code runs concurrently — multiple fibers execute in the same thread
2. I/O operations yield — network calls, DB queries, file I/O all context switch
3. Avoid blocking the scheduler — blocking I/O stalls ALL fibers

**HTTP Clients:**
```ruby
# ❌ BAD - Blocks the fiber scheduler
response = HTTParty.get(url)
response = Net::HTTP.get(uri)

# ✅ GOOD - Non-blocking, fiber-aware
Sync do
  response = Async::HTTP::Internet.get(url)
  data = response.read
ensure
  response&.close
end
```

**Fiber Safety:**

| Unsafe Pattern | Safe Alternative |
|----------------|------------------|
| `Thread.current[:key]` | `Fiber[:key]` for per-request state |
| `@@class_var` | Dependency injection / instance state |
| Lazy `@mutex ||= Mutex.new` | Initialize mutex eagerly at class load |

**Background Jobs (Sidekiq):** Blocking I/O is OK in jobs — separate process.

---

## ActiveRecord Performance

| Pattern | Why | Example |
|---------|-----|---------|
| `find_each`/`in_batches` | Avoids loading all into memory | `User.find_each { \|u\| ... }` |
| NO query methods in instance methods | Causes N+1 | Use `select`/`reject` instead |
| `select` only needed columns | Reduces memory/time | `.select(:id, :name)` |
| Database aggregations | Much faster than Ruby | `average`, `sum`, `count` |
| Bulk operations | Single query vs N | `update_all`, `destroy_all` |

## Migration Guidelines

**Prefer separate tables over adding columns** for new features, external sync state, or tracking metadata:

```ruby
# ✅ GOOD - Separate infrastructure table
create_table :item_sync_states do |t|
  t.references :item, null: false
  t.string :status, default: 'pending'
  t.datetime :last_synced_at
end

# ❌ AVOID - Polluting domain model
add_column :items, :sync_status, :string
add_column :items, :last_synced_at, :datetime
```

**Exception:** Denormalization is OK for hot-path performance when JOINs add measurable latency.

## Configuration

Application code must never depend on configuration sources (ENV, credentials, YAML) directly. Use named configuration objects.

```ruby
class PaymentsConfig < ApplicationConfig
  attr_config :api_key, :webhook_secret, enabled: true

  required :api_key
  coerce_types enabled: :boolean
end
```

**Rules:**
- Sensitive secrets → Rails credentials (per-environment)
- Non-sensitive settings → Named YAML files with defaults
- Overrides → Environment variables
- Personal dev secrets → `*.local.yml` (gitignored)
- **Never** use `ENV["X"]` directly in application code — access via config objects
- **Never** use `Rails.env.production?` in business logic — use config flags instead
- Essential secrets missing at boot → raise in initializer (fail fast)
