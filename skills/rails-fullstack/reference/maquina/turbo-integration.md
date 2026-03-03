# Turbo Integration

Patterns for using maquina_components with Turbo Drive, Frames, Streams, and Morphing.

---

## Turbo Decision Framework

| Scenario | Approach | Why |
|----------|----------|-----|
| Full page navigation | **Turbo Drive** (default) | Fast, no configuration needed |
| Inline editing | **Turbo Frame** | Scoped replacement, preserves page state |
| Modal/dialog content | **Turbo Frame** | Isolated, lazy-loaded |
| Real-time updates | **Turbo Stream** via broadcast | Push from server |
| Form submission feedback | **Turbo Stream** response | Multiple DOM updates |
| Full page refresh with state | **Morph** | Preserves scroll, form state |
| List item updates | **Turbo Stream** | Targeted prepend/append/replace |

---

## Turbo Frames

### Inline Editing

```erb
<%# Show view %>
<%= turbo_frame_tag dom_id(@service) do %>
  <%= render "components/card" do %>
    <%= render "components/card/content" do %>
      <div class="flex justify-between">
        <div>
          <h3 class="font-medium"><%= @service.name %></h3>
          <p class="text-muted-foreground"><%= format_money(@service.price_cents) %></p>
        </div>
        <%= link_to edit_service_path(@service), 
            data: { component: "button", variant: "ghost", size: "icon-sm" } do %>
          <%= icon_for :edit, class: "size-4" %>
        <% end %>
      </div>
    <% end %>
  <% end %>
<% end %>
```

### Lazy Loading Frames

```erb
<%= turbo_frame_tag "activity_feed", src: activity_feed_path, loading: :lazy do %>
  <div class="animate-pulse space-y-2">
    <div class="h-4 bg-muted rounded w-3/4"></div>
    <div class="h-4 bg-muted rounded w-1/2"></div>
  </div>
<% end %>
```

### Breaking Out of Frames

```erb
<%= link_to "Full Page", booking_path(@booking), data: { turbo_frame: "_top" } %>
```

---

## Turbo Streams

### Controller Response

```ruby
def create
  @booking = current_account.bookings.build(booking_params)
  
  if @booking.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bookings_path, notice: t(".created") }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

```erb
<%# app/views/bookings/create.turbo_stream.erb %>
<%= turbo_stream.prepend "bookings_list" do %>
  <%= render "bookings/row", booking: @booking %>
<% end %>

<%= turbo_stream.replace "bookings_count" do %>
  <%= render "bookings/count", count: current_account.bookings.today.count %>
<% end %>
```

### Stream Actions Reference

| Action | Usage |
|--------|-------|
| `append` | Add to end of container |
| `prepend` | Add to beginning of container |
| `replace` | Replace entire element |
| `update` | Replace element's innerHTML |
| `remove` | Remove element |
| `before` | Insert before element |
| `after` | Insert after element |
| `morph` | Morph element (preserves state) |
| `refresh` | Trigger page refresh |

---

## Broadcasts (Real-time)

```ruby
class Booking < ApplicationRecord
  after_create_commit -> { broadcast_prepend_to account, :bookings }
  after_update_commit -> { broadcast_replace_to account, :bookings }
  after_destroy_commit -> { broadcast_remove_to account, :bookings }
end
```

```erb
<%= turbo_stream_from current_account, :bookings %>

<div id="bookings">
  <%= render @bookings %>
</div>
```

---

## Morphing

```erb
<%# Layout: Enable morphing %>
<html>
<head>
  <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
</head>
```

```erb
<%# Exclude elements from morph %>
<div data-turbo-permanent id="sidebar_state">...</div>
```

---

## Form Patterns with Turbo

### Confirmation Dialog

```erb
<%= button_to booking_path(@booking), 
    method: :delete,
    data: { 
      component: "button", 
      variant: "destructive",
      turbo_confirm: t(".confirm_delete"),
      turbo_method: :delete
    } do %>
  <%= icon_for :trash, class: "size-4 mr-1" %><%= t(".delete") %>
<% end %>
```

### Submit Button Loading State

```erb
<%= form_with model: @booking, class: "group", data: { component: "form" } do |f| %>
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
<% end %>
```

### Validation Errors

```ruby
def create
  @booking = current_account.bookings.build(booking_params)
  
  if @booking.save
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @booking }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

---

## Component-Specific Patterns

### Card with Frame Content

```erb
<%= render "components/card" do %>
  <%= render "components/card/header" do %>
    <%= render "components/card/title", text: t(".recent_activity") %>
  <% end %>
  <%= render "components/card/content" do %>
    <%= turbo_frame_tag "activity_list", src: activities_path, loading: :lazy do %>
      <div class="space-y-3">
        <% 3.times do %>
          <div class="animate-pulse flex gap-3">
            <div class="h-8 w-8 bg-muted rounded-full"></div>
            <div class="flex-1 space-y-2">
              <div class="h-4 bg-muted rounded w-3/4"></div>
              <div class="h-3 bg-muted rounded w-1/2"></div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
  <% end %>
<% end %>
```

### Table with Broadcast Updates

```erb
<%= turbo_stream_from current_account, :bookings %>

<%= render "components/table" do %>
  <%= render "components/table/header" do %>
    <%= render "bookings/table_header" %>
  <% end %>
  <%= render "components/table/body", id: "bookings_list" do %>
    <% @bookings.each do |booking| %>
      <%= render "bookings/table_row", booking: booking %>
    <% end %>
  <% end %>
<% end %>
```

### Empty State Handling

```erb
<div id="bookings_container">
  <% if @bookings.any? %>
    <div id="bookings_list"><%= render @bookings %></div>
  <% else %>
    <div id="empty_state"><%= render "bookings/empty_state" %></div>
  <% end %>
</div>
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.remove "empty_state" %>
<%= turbo_stream.prepend "bookings_list", @booking %>
```

---

## Performance Tips

### Debounce Search Input

```javascript
// debounce_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }
}
```

### Prefetch Links

```erb
<%= link_to booking_path(@booking), data: { turbo_prefetch: true } do %>
  View Details
<% end %>
```
