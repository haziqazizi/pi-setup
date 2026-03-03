# Layout Patterns

Page structure, grid systems, and responsive design patterns using maquina_components.

---

## Page Structure

### Standard App Layout

The sidebar + inset pattern provides the foundation for dashboard-style applications:

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" class="h-full">
<head>
  <title><%= content_for(:title) || "App" %></title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
  <%= javascript_importmap_tags %>
</head>

<body class="h-full overflow-hidden bg-background font-sans antialiased">
  <%= render "components/sidebar/provider", 
      default_open: app_sidebar_open?,
      variant: :inset do %>
    
    <%= render "layouts/sidebar" %>
    
    <%= render "components/sidebar/inset" do %>
      <%= render "components/header" do %>
        <%= render "components/sidebar/trigger", icon_name: :panel_left %>
        
        <div class="flex-1">
          <%= yield :header %>
        </div>
        
        <div class="flex items-center gap-2">
          <%= yield :header_actions %>
        </div>
      <% end %>
      
      <main class="flex-1 overflow-y-auto p-6">
        <%= yield %>
      </main>
    <% end %>
  <% end %>
</body>
</html>
```

### Public Page Layout (No Sidebar)

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>" class="h-full">
<head>
  <title><%= content_for(:title) %></title>
  <%= csrf_meta_tags %>
  <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
  <%= javascript_importmap_tags %>
</head>

<body class="min-h-full bg-background font-sans antialiased">
  <header class="border-b bg-card">
    <div class="container mx-auto px-4 py-4">
      <%= yield :header %>
    </div>
  </header>
  
  <main class="container mx-auto px-4 py-8">
    <%= yield %>
  </main>
  
  <footer class="border-t bg-muted/50 mt-auto">
    <div class="container mx-auto px-4 py-6">
      <%= yield :footer %>
    </div>
  </footer>
</body>
</html>
```

---

## Content Layouts

### Dashboard Page

```erb
<div class="space-y-6">
  <%# Stats Row %>
  <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
    <%= render "dashboard/stat_card", title: t(".stats.revenue"), value: format_money(@stats[:revenue]) %>
  </div>
  
  <%# Main Content Grid %>
  <div class="grid gap-6 lg:grid-cols-3">
    <div class="lg:col-span-2 space-y-6">
      <%= render "dashboard/bookings_table", bookings: @today_bookings %>
    </div>
    <div class="space-y-6">
      <%= render "dashboard/activity_feed", activities: @recent_activities %>
    </div>
  </div>
</div>
```

### List Page

```erb
<%= render "components/card" do %>
  <%= render "components/card/header", layout: :row do %>
    <div>
      <%= render "components/card/title", text: t(".title") %>
      <%= render "components/card/description", text: t(".description") %>
    </div>
    <%= render "components/card/action" do %>
      <%= render "bookings/filters", filter: @filter %>
    <% end %>
  <% end %>
  
  <%= render "components/card/content" do %>
    <% if @bookings.any? %>
      <%= render "components/table", container: false do %>...table...<% end %>
    <% else %>
      <%= render "bookings/empty_state" %>
    <% end %>
  <% end %>
  
  <% if @pagy.pages > 1 %>
    <%= render "components/card/footer", align: :between do %>
      <span class="text-sm text-muted-foreground">
        <%= t(".showing", from: @pagy.from, to: @pagy.to, count: @pagy.count) %>
      </span>
      <%= pagination_nav(@pagy, :bookings_path, show_labels: false) %>
    <% end %>
  <% end %>
<% end %>
```

### Detail/Show Page

```erb
<div class="grid gap-6 lg:grid-cols-3">
  <div class="lg:col-span-2 space-y-6">
    <%= render "components/card" do %>
      <%= render "components/card/header" do %>
        <%= render "components/card/title", text: t(".details") %>
      <% end %>
      <%= render "components/card/content" do %>
        <%= render "bookings/detail_fields", booking: @booking %>
      <% end %>
    <% end %>
  </div>
  
  <div class="space-y-6">
    <%= render "bookings/status_card", booking: @booking %>
    <%= render "bookings/client_card", client: @booking.client %>
  </div>
</div>
```

### Form Page

```erb
<div class="max-w-2xl mx-auto">
  <%= render "components/card" do %>
    <%= render "components/card/header" do %>
      <%= render "components/card/title", text: t(".title") %>
      <%= render "components/card/description", text: t(".description") %>
    <% end %>
    <%= render "components/card/content" do %>
      <%= render "bookings/form", booking: @booking %>
    <% end %>
  <% end %>
</div>
```

---

## Grid Patterns

```erb
<%# 2 columns on tablet, 4 on desktop %>
<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">...</div>

<%# 2 columns, main + sidebar %>
<div class="grid gap-6 lg:grid-cols-3">
  <div class="lg:col-span-2">Main content</div>
  <div>Sidebar</div>
</div>

<%# Auto-fit cards %>
<div class="grid gap-4 grid-cols-[repeat(auto-fit,minmax(280px,1fr))]">...</div>
```

---

## Card Patterns

### Stats Card

```erb
<%= render "components/card" do %>
  <%= render "components/card/header", css_classes: "pb-2" do %>
    <div class="flex items-center justify-between">
      <%= render "components/card/title", text: title, size: :sm %>
      <% if icon %>
        <%= icon_for icon, class: "size-4 text-muted-foreground" %>
      <% end %>
    </div>
  <% end %>
  <%= render "components/card/content", css_classes: "pt-0" do %>
    <div class="text-2xl font-bold"><%= value %></div>
  <% end %>
<% end %>
```

### Card List Item

```erb
<div class="space-y-4">
  <% @items.each do |item| %>
    <%= render "components/card", css_classes: "hover:border-primary/50 transition-colors" do %>
      <%= render "components/card/content", css_classes: "p-4" do %>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-muted">
              <%= icon_for item_icon(item), class: "size-5" %>
            </div>
            <div>
              <p class="font-medium"><%= item.name %></p>
              <p class="text-sm text-muted-foreground"><%= item.description %></p>
            </div>
          </div>
          <%= render "components/badge", variant: status_variant(item.status) do %>
            <%= item.status.humanize %>
          <% end %>
        </div>
      <% end %>
    <% end %>
  <% end %>
</div>
```

---

## Responsive Patterns

### Breakpoint Reference

| Prefix | Min Width | Typical Device |
|--------|-----------|----------------|
| (none) | 0px | Mobile phones |
| `sm:` | 640px | Large phones |
| `md:` | 768px | Tablets |
| `lg:` | 1024px | Laptops |
| `xl:` | 1280px | Desktops |
| `2xl:` | 1536px | Large desktops |

### Responsive Table Pattern

```erb
<%# Desktop: Table %>
<div class="hidden md:block">
  <%= render "components/table" do %>...<% end %>
</div>

<%# Mobile: Card list %>
<div class="md:hidden space-y-4">
  <% @items.each do |item| %>
    <%= render "items/mobile_card", item: item %>
  <% end %>
</div>
```

---

## Spacing Patterns

```erb
<%# Page sections %>
<div class="space-y-6">...</div>

<%# Constrained content width %>
<div class="max-w-2xl">...</div>      <%# ~672px - Forms %>
<div class="max-w-4xl">...</div>      <%# ~896px - Content %>
<div class="max-w-6xl">...</div>      <%# ~1152px - Wide content %>

<%# Centered constrained %>
<div class="max-w-2xl mx-auto">...</div>
```

---

## Common Partial Patterns

### Row Actions Partial

```erb
<%= render "components/dropdown_menu" do %>
  <%= render "components/dropdown_menu/trigger", as_child: true do %>
    <button type="button"
            data-component="button"
            data-variant="ghost"
            data-size="icon-sm"
            data-dropdown-menu-target="trigger"
            data-action="dropdown-menu#toggle">
      <%= icon_for :more_horizontal, class: "size-4" %>
    </button>
  <% end %>
  <%= render "components/dropdown_menu/content", align: :end do %>
    <%= render "components/dropdown_menu/item", href: edit_path do %>
      <%= icon_for :edit, class: "size-4" %> <%= t("actions.edit") %>
    <% end %>
    <%= render "components/dropdown_menu/separator" %>
    <%= render "components/dropdown_menu/item", 
        href: delete_path, 
        method: :delete,
        variant: :destructive,
        data: { turbo_confirm: t("confirm.delete") } do %>
      <%= icon_for :trash, class: "size-4" %> <%= t("actions.delete") %>
    <% end %>
  <% end %>
<% end %>
```

---

## Dark Mode

Components automatically support dark mode via CSS variables. Add `.dark` class to `<html>`:

```erb
<html lang="<%= I18n.locale %>" class="h-full <%= dark_mode? ? 'dark' : '' %>">
```
