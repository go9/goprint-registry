defmodule GoprintRegistryWeb.Components.Layout.SidebarNav do
  use GoprintRegistryWeb, :html

  attr :current_user, :map, required: true
  attr :mobile, :boolean, default: false

  def sidebar_nav(assigns) do
    ~H"""
    <.navlist>
      <.navlink navigate="/dashboard">
        <.icon name="hero-home" class="size-5" /> Dashboard
      </.navlink>
      <.navlink navigate="/clients">
        <.icon name="hero-computer-desktop" class="size-5" /> Clients
      </.navlink>
      <.navlink navigate="/users/settings">
        <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
      </.navlink>
      <.navlink navigate="/users/api-keys">
        <.icon name="hero-key" class="size-5" /> API Keys
      </.navlink>
    </.navlist>

    <%= if @current_user && @current_user.is_admin do %>
      <.navlist>
        <.navlink navigate="/admin">
          <.icon name="hero-shield-check" class="size-5" /> Admin Dashboard
        </.navlink>
      </.navlist>
    <% end %>

    <%= if @mobile do %>
      <.navlist class="mt-auto!">
        <.navlink navigate="/users/api-keys">
          <.icon name="hero-key" class="size-5" /> API Keys
        </.navlink>
        <.navlink navigate="/users/settings">
          <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
        </.navlink>
        <.navlink href="/users/log-out" method="delete">
          <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Sign out
        </.navlink>
      </.navlist>
    <% end %>
    """
  end
end
