---
name: rspec-testing
description: "RSpec testing patterns and best practices for Rails applications. Covers three-layer testing strategy, flaky test prevention, factory best practices, and debugging techniques. Use when writing request specs, model specs, or debugging test failures."
---

# RSpec Testing Patterns

## Three-Layer Testing Strategy

| Layer | Location | Network | Purpose |
|-------|----------|---------|---------|
| Contract | `spec/adapters/` | ✅ Real API | Verify external APIs haven't changed |
| Model | `spec/models/` | ❌ Mocked | Test business logic |
| Request | `spec/requests/` | ❌ Mocked | Test HTTP routing + JSON responses |

## Flaky Test Prevention

### Common Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `json[:items].first` | Assumes ordering | Use `.find { \|x\| x[:id] == expected.id }` |
| Ambiguous query matching multiple records | Non-deterministic results | Use specific query matching exactly one record |
| `Timecop.freeze` without cleanup | Time leaks to next test | Use `around` hooks or configure auto-return |
| Global state modification | Leaks between parallel workers | Use `around` hooks with `ensure` cleanup |
| Random data collisions | Intermittent uniqueness failures | Use factory sequences, not `SecureRandom` |

### Writing Flake-Resistant Tests

```ruby
# ❌ BAD - Ordering assumption
item_data = json[:items].first
expect(item_data[:title]).to eq('Expected Title')

# ✅ GOOD - Explicit matching
item_data = json[:items].find { |i| i[:id] == item1.id }
expect(item_data[:title]).to eq('Expected Title')
```

```ruby
# ❌ BAD - Random collisions
let!(:users) { 50.times.map { create(:user, username: "user_#{SecureRandom.hex(4)}") } }

# ✅ GOOD - Sequences guarantee uniqueness
let!(:users) { create_list(:user, 50) }
```

### Debugging Flaky Tests

```bash
# Reproduce with same seed from CI
bundle exec rspec spec/path/to/spec.rb --seed 12345

# Bisect to find minimal reproduction
bundle exec rspec spec/requests --bisect --seed 12345

# Run single spec in isolation
bundle exec rspec spec/requests/api/v2/items_spec.rb:165
```

## Factory Best Practices

1. **Use sequences** for all unique fields — never rely on random generation
2. **Use `let_it_be`** (from `test-prof`) for shared fixtures that don't change between examples
3. **Use `create_default`** for common associations to reduce factory overhead
4. **Use `create_list`** instead of manual loops
5. **Trust transactional fixtures** — `use_transactional_fixtures = true` auto-cleans after each test

```ruby
# Factory with sequences
FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user_#{n}" }
    sequence(:email) { |n| "user_#{n}@example.com" }
  end
end

# Shared fixtures (don't recreate per example)
let_it_be(:admin) { create(:user, role: :admin) }
let_it_be(:items) { create_list(:item, 5, seller: admin) }
```

## Request Spec Patterns

```ruby
RSpec.describe "Api::V2::Items", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { auth_headers_for(user) }

  describe "GET /api/v2/items" do
    let!(:item) { create(:item, title: "Test Item") }

    it "returns items" do
      get "/api/v2/items", headers: auth_headers
      expect(response).to have_http_status(:ok)

      item_data = json[:data].find { |i| i[:id] == item.id }
      expect(item_data[:title]).to eq("Test Item")
    end
  end
end
```

## When Writing New Tests

1. **Never use `.first`/`.last`** on query results unless ORDER BY is explicit
2. **Prefer specific queries** that match exactly one record
3. **Clean up global state** in `ensure` blocks for `around` hooks
4. **Don't mock what you don't own** — mock adapters at the boundary, not deep internals
5. **Test behavior, not implementation** — assert on HTTP responses and side effects, not internal method calls
