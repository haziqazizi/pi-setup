# Form Patterns

Building forms with maquina_components, validation, error handling, and common form patterns.

---

## Form Fundamentals

### Basic Form Structure

```erb
<%= form_with model: @user, data: { component: "form" } do |f| %>
  <fieldset data-component="fieldset">
    <legend data-component="legend"><%= t(".account_info") %></legend>
    
    <div data-form-part="group">
      <%= f.label :name, data: { component: "label", required: true } %>
      <%= f.text_field :name, data: { component: "input" }, 
          placeholder: t(".name_placeholder") %>
      <% if @user.errors[:name].any? %>
        <p data-form-part="error"><%= @user.errors[:name].first %></p>
      <% end %>
    </div>
    
    <div data-form-part="group">
      <%= f.label :email, data: { component: "label", required: true } %>
      <%= f.email_field :email, data: { component: "input" },
          placeholder: t(".email_placeholder") %>
      <p data-form-part="description"><%= t(".email_hint") %></p>
      <% if @user.errors[:email].any? %>
        <p data-form-part="error"><%= @user.errors[:email].first %></p>
      <% end %>
    </div>
  </fieldset>
  
  <div data-form-part="actions">
    <%= f.submit t(".save"), data: { component: "button", variant: "primary" } %>
    <%= link_to t(".cancel"), users_path, data: { component: "button", variant: "outline" } %>
  </div>
<% end %>
```

### Field Group Pattern

Every form field should be wrapped in a group:

```erb
<div data-form-part="group">
  <%= f.label :field_name, data: { component: "label" } %>
  <%= f.text_field :field_name, data: { component: "input" } %>
  <p data-form-part="description">Optional help text</p>
  <% if @model.errors[:field_name].any? %>
    <p data-form-part="error"><%= @model.errors[:field_name].first %></p>
  <% end %>
</div>
```

### Required Fields

```erb
<%# Add required indicator to label %>
<%= f.label :name, data: { component: "label", required: true } %>

<%# Also add HTML required attribute for browser validation %>
<%= f.text_field :name, data: { component: "input" }, required: true %>
```

---

## Input Best Practices

**Every input should include appropriate HTML5 attributes** for validation, accessibility, and optimal mobile experience.

### Required Attributes Checklist

| Attribute | When to Use | Example |
|-----------|-------------|---------|
| `type` | Always — use correct type for data | `email`, `tel`, `url`, `number`, `date` |
| `required` | Mandatory fields | `required: true` |
| `maxlength` | Text inputs — prevents overflow | `maxlength: 100` |
| `minlength` | When minimum length matters | `minlength: 2` |
| `pattern` | Custom format validation | `pattern: "[A-Z]{2}[0-9]{4}"` |
| `min` / `max` | Number/date ranges | `min: 0, max: 100` |
| `step` | Number increments | `step: 0.01` for money |
| `inputmode` | Mobile keyboard optimization | `inputmode: "numeric"` |
| `autocomplete` | Autofill hints | `autocomplete: "email"` |

### Complete Input Examples

```erb
<%# Name - text with sensible limits %>
<%= f.text_field :name,
    data: { component: "input" },
    required: true,
    minlength: 2,
    maxlength: 100,
    autocomplete: "name" %>

<%# Email - correct type, maxlength per RFC %>
<%= f.email_field :email,
    data: { component: "input" },
    required: true,
    maxlength: 254,
    autocomplete: "email" %>

<%# Phone - pattern for flexibility, tel keyboard %>
<%= f.phone_field :phone,
    data: { component: "input" },
    required: true,
    maxlength: 20,
    pattern: "[+]?[0-9\\s\\-()]+",
    inputmode: "tel",
    autocomplete: "tel" %>

<%# Money - number with cents precision %>
<%= f.number_field :price,
    data: { component: "input" },
    required: true,
    min: 0,
    max: 999999.99,
    step: 0.01,
    inputmode: "decimal" %>

<%# URL - correct type, sensible max %>
<%= f.url_field :website,
    data: { component: "input" },
    maxlength: 2000,
    autocomplete: "url",
    placeholder: "https://" %>

<%# Password - minimum length for security %>
<%= f.password_field :password,
    data: { component: "input" },
    required: true,
    minlength: 8,
    maxlength: 128,
    autocomplete: "new-password" %>
```

### Common Maxlength Values

| Field Type | Recommended Maxlength | Rationale |
|------------|----------------------|-----------|
| Name | 100 | Handles long names |
| Email | 254 | RFC 5321 limit |
| Phone | 20 | E.164 with formatting |
| URL | 2000 | Browser URL limits |
| Short text | 255 | Standard varchar |
| Description | 1000-5000 | Reasonable for textarea |
| Slug/username | 50 | URL-friendly |
| Password | 128 | Security + practicality |

---

## Validation & Error Handling

### ✅ Recommended: Inline Errors + Flash

**Always prefer inline field errors with a brief flash notification** over an alert containing a list of all errors.

```erb
<%= form_with model: @user, data: { component: "form" } do |f| %>
  <div data-form-part="group">
    <%= f.label :name, data: { component: "label", required: true } %>
    <%= f.text_field :name, 
        data: { component: "input" },
        required: true,
        minlength: 2,
        maxlength: 100,
        aria: { 
          invalid: @user.errors[:name].any?,
          describedby: ("name-error" if @user.errors[:name].any?)
        } %>
    <% if @user.errors[:name].any? %>
      <p data-form-part="error" id="name-error"><%= @user.errors[:name].first %></p>
    <% end %>
  </div>
  
  <div data-form-part="actions">
    <%= f.submit t(".save"), data: { component: "button", variant: "primary" } %>
  </div>
<% end %>
```

### ❌ Avoid: Alert with Error List

```erb
<%# Don't do this - users have to match errors to fields %>
<% if @user.errors.any? %>
  <%= render "components/alert", variant: :destructive do %>
    <%= render "components/alert/title", text: t("errors.validation_failed") %>
    <%= render "components/alert/description" do %>
      <ul class="list-disc pl-4">
        <% @user.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    <% end %>
  <% end %>
<% end %>
```

### Field Error Helper

Create a helper to reduce repetition:

```ruby
# app/helpers/form_helper.rb
module FormHelper
  def form_field(form, field, options = {}, &block)
    model = form.object
    has_error = model.errors[field].any?
    
    content_tag :div, data: { form_part: "group" } do
      concat form.label(field, data: { component: "label", required: options[:required] })
      concat capture(&block)
      
      if options[:description]
        concat content_tag(:p, options[:description], data: { form_part: "description" })
      end
      
      if has_error
        concat content_tag(:p, model.errors[field].first, data: { form_part: "error" })
      end
    end
  end
end
```

---

## Loading States

Turbo automatically adds `aria-busy="true"` to forms during submission. Use this with Tailwind's `group-aria-busy:` modifier for loading states — no JavaScript required.

### ✅ Recommended: aria-busy Spinner Pattern

```erb
<%= form_with model: @booking, class: "group", data: { component: "form" } do |f| %>
  <%# ... form fields ... %>
  
  <div data-form-part="actions">
    <%= f.button type: :submit, data: { component: "button", variant: "primary" } do %>
      <span class="group-aria-busy:hidden"><%= t(".save") %></span>
      <svg class="hidden group-aria-busy:block animate-spin size-5" 
           fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" 
                stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" 
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    <% end %>
  </div>
<% end %>
```

### Alternative: data-turbo-submits-with

For simple text replacement without a spinner:

```erb
<%= f.submit t(".save"), 
    data: { 
      component: "button", 
      variant: "primary",
      turbo_submits_with: t(".saving")
    } %>
```

---

## Common Form Patterns

### Login Form

```erb
<%= form_with url: session_path, data: { component: "form" } do |f| %>
  <div data-form-part="group">
    <%= f.label :phone, t(".phone"), data: { component: "label" } %>
    <%= f.phone_field :phone, data: { component: "input" },
        required: true,
        autofocus: true,
        autocomplete: "tel",
        placeholder: "+52 55 1234 5678" %>
  </div>
  
  <div data-form-part="actions">
    <%= f.submit t(".continue"), 
        data: { component: "button", variant: "primary" },
        class: "w-full" %>
  </div>
<% end %>
```

### Form Actions

```erb
<div data-form-part="actions">
  <%= f.submit t(".save"), data: { component: "button", variant: "primary" } %>
  <%= link_to t(".cancel"), back_path, data: { component: "button", variant: "outline" } %>
</div>

<%# Right aligned %>
<div data-form-part="actions" data-align="end">
  <%= f.submit t(".save"), data: { component: "button", variant: "primary" } %>
</div>

<%# Space between %>
<div data-form-part="actions" data-align="between">
  <%= link_to t(".back"), previous_path, data: { component: "button", variant: "ghost" } %>
  <%= f.submit t(".publish"), data: { component: "button", variant: "primary" } %>
</div>
```
