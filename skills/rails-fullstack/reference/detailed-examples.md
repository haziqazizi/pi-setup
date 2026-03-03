# Detailed Examples

## View Components

### Setup

Use the `view_component` gem. Define a base class:

```ruby
class ApplicationComponent < ViewComponent::Base
  extend Dry::Initializer[undefined: false]
end
```

### Basic Component

```ruby
# app/components/search_box/component.rb
class SearchBox::Component < ApplicationComponent
  option :url
  option :placeholder, optional: true
  option :variant, default: proc { :full }

  def before_render
    @placeholder ||= t(".placeholder")
  end

  private

  def button? = variant == :full
end
```

```erb
<%# app/components/search_box/component.html.erb %>
<%= form_with(url:) do |f| %>
  <div><i class="fa fa-search"></i></div>
  <%= f.search_field :q, placeholder: %>
  <% if button? %>
    <%= f.submit "Search" %>
  <% end %>
<% end %>
```

```yaml
# app/components/search_box/component.yml
en:
  placeholder: "Search"
```

### Usage in Templates

```erb
<%= render SearchBox::Component.new(url: search_path) %>
<%= render SearchBox::Component.new(url: search_path, variant: :compact) %>
```

### Testing Components

```ruby
class SearchBox::ComponentTest < ViewComponent::TestCase
  def test_render_full
    render_inline(SearchBox::Component.new(url: "#", placeholder: "Find"))
    assert_selector "input[type='submit']"
    assert_selector "input[type='search'][placeholder='Find']"
  end

  def test_render_compact
    render_inline(SearchBox::Component.new(url: "#", variant: :compact))
    assert_no_selector "input[type='submit']"
  end
end
```

---

## Presenters

### Open Presenters (Decorators)

Use `SimpleDelegator` — all model methods pass through:

```ruby
class UserPresenter < SimpleDelegator
  def short_name
    name.squish.split(/\s/).then do |parts|
      parts[0..-2].map { _1[0] + "." }.join + parts.last
    end
  end
end
```

### Closed Presenters

Expose only what's needed via delegation:

```ruby
class UserPresenter
  delegate :id, :to_model, to: :user

  private attr_reader :user
  def initialize(user) = @user = user

  def short_name
    # formatting logic
  end
end
```

### Multi-Model Presenters

```ruby
class User::BookPresenter < BookPresenter
  private attr_reader :book_read
  delegate :read?, :read_at, :score, to: :book_read

  def initialize(book, book_read)
    super(book)
    @book_read = book_read
  end

  def progress_icon
    read? ? "fa-circle-check" : "fa-clock"
  end

  def score_class
    case score
    when 0..2 then "text-red-600"
    when 3...4 then "text-yellow-600"
    when 4... then "text-green-600"
    end
  end
end
```

### Presenter Libraries

- **SimpleDelegator** (built-in) — simplest, good default
- **Keynote** — caching, view context access, `k(object)` helper
- **Draper** — popular but heavier

---

## Form Objects

### Base Class

```ruby
class ApplicationForm
  include ActiveModel::API
  include ActiveModel::Attributes

  define_callbacks :save, only: :after
  define_callbacks :commit, only: :after

  class << self
    def after_save(...)  = set_callback(:save, :after, ...)
    def after_commit(...) = set_callback(:commit, :after, ...)

    def from(params)
      new(params.permit(attribute_names.map(&:to_sym)))
    end
  end

  def save
    return false unless valid?
    with_transaction do
      AfterCommitEverywhere.after_commit { run_callbacks(:commit) }
      run_callbacks(:save) { submit! }
    end
  end

  def model_name
    ActiveModel::Name.new(nil, nil, self.class.name.sub(/Form$/, ""))
  end

  private

  def with_transaction(&) = ApplicationRecord.transaction(&)
  def submit! = raise NotImplementedError

  def merge_errors!(other)
    other.errors.each do |e|
      errors.add(e.attribute, e.type, message: e.message)
    end
  end
end
```

### Single-Model Form

```ruby
class InvitationForm < ApplicationForm
  attribute :email
  attribute :send_copy, :boolean

  attr_accessor :sender

  validates :email, presence: true

  after_commit :deliver_invitation
  after_commit :deliver_invitation_copy, if: :send_copy

  private

  attr_reader :user

  def submit!
    @user = User.create!(email:)
  end

  def deliver_invitation
    UserMailer.invite(user).deliver_later
  end

  def deliver_invitation_copy
    UserMailer.invite_copy(sender, user).deliver_later if sender
  end
end
```

### Multi-Model Form

```ruby
class RegistrationForm < ApplicationForm
  attribute :name
  attribute :email
  attribute :should_create_project, :boolean
  attribute :project_name

  validates :project_name, presence: true, if: :should_create_project
  validate :user_is_valid

  attr_reader :user

  after_save :create_initial_project, if: :should_create_project

  def initialize(...)
    super
    @user = User.new(email:, name:)
  end

  private

  def submit!
    user.save!
  end

  def create_initial_project
    user.projects.create!(name: project_name)
  end

  def user_is_valid
    return if user.valid?
    merge_errors!(user)
  end
end
```

### Model-Less Form

```ruby
class FeedbackForm < ApplicationForm
  attribute :name
  attribute :email
  attribute :message

  validates :name, :email, :message, presence: true
  validates :message, length: { maximum: 160 }

  after_commit { SystemMailer.feedback(email, name, message).deliver_later }

  def submit! = true
end
```

### Controller Usage

```ruby
class InvitationsController < ApplicationController
  def new
    @invitation_form = InvitationForm.new
  end

  def create
    @invitation_form = InvitationForm.from(params.require(:invitation))
    @invitation_form.sender = current_user

    if @invitation_form.save
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

### View Usage (Action View Compatible)

```erb
<%= form_for(@invitation_form) do |form| %>
  <%= form.label :email %>
  <%= form.text_field :email %>
  <%= form.label :send_copy, "Send me the copy" %>
  <%= form.check_box :send_copy %>
  <%= form.submit "Invite" %>
<% end %>
```

---

## Event-Driven Alternative for Callbacks

For remote peer communication (analytics, CRM sync), use ActiveSupport::Notifications:

```ruby
# Model — publish lifecycle events only
class User < ApplicationRecord
  after_commit { ActiveSupport::Notifications.instrument("updated.user", user: self) }
end

# Subscriber — separate file
class UserCRMSubscriber < ActiveSupport::Subscriber
  def updated(event)
    user = event.payload[:user]
    CRMAdapter.sync(user)
  end
end
UserCRMSubscriber.attach_to :user
```
