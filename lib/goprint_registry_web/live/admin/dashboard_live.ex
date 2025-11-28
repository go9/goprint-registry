defmodule GoprintRegistryWeb.Admin.DashboardLive do
  use GoprintRegistryWeb, :live_view

  alias GoprintRegistry.Accounts
  alias GoprintRegistry.Clients

  @impl true
  def mount(_params, _session, socket) do
    user_count = Accounts.count_users()
    client_count = Clients.count_clients()
    active_clients = Clients.count_active_clients()
    
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:user_count, user_count)
     |> assign(:client_count, client_count)
     |> assign(:active_clients, active_clients)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold leading-6 text-foreground">Admin Dashboard</h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Overview of system statistics and quick access to administrative functions.
          </p>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Users Card -->
        <div class="overflow-hidden rounded-lg bg-card shadow border border-base">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-user-group" class="h-6 w-6 text-muted-foreground" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-muted-foreground truncate">Total Users</dt>
                  <dd class="text-3xl font-semibold text-foreground"><%= @user_count %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-muted/50 px-5 py-3">
            <div class="text-sm">
              <.link navigate={~p"/admin/users"} class="font-medium text-primary hover:text-primary/80">
                View all users →
              </.link>
            </div>
          </div>
        </div>

        <!-- Clients Card -->
        <div class="overflow-hidden rounded-lg bg-card shadow border border-base">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-computer-desktop" class="h-6 w-6 text-muted-foreground" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-muted-foreground truncate">Total Clients</dt>
                  <dd class="text-3xl font-semibold text-foreground"><%= @client_count %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-muted/50 px-5 py-3">
            <div class="text-sm">
              <.link navigate={~p"/admin/clients"} class="font-medium text-primary hover:text-primary/80">
                View all clients →
              </.link>
            </div>
          </div>
        </div>

        <!-- Active Clients Card -->
        <div class="overflow-hidden rounded-lg bg-card shadow border border-base">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-signal" class="h-6 w-6 text-success" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-muted-foreground truncate">Active Clients</dt>
                  <dd class="text-3xl font-semibold text-foreground"><%= @active_clients %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-muted/50 px-5 py-3">
            <div class="text-sm text-muted-foreground">
              Connected in last 5 minutes
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-foreground">Quick Actions</h2>
        <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.link
            navigate={~p"/admin/users"}
            class="relative rounded-lg border border-base bg-card px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-primary focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary"
          >
            <div class="flex-1 min-w-0">
              <span class="absolute inset-0" aria-hidden="true"></span>
              <p class="text-sm font-medium text-foreground">Manage Users</p>
              <p class="text-sm text-muted-foreground truncate">View and edit user accounts</p>
            </div>
          </.link>

          <.link
            navigate={~p"/admin/clients"}
            class="relative rounded-lg border border-base bg-card px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-primary focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary"
          >
            <div class="flex-1 min-w-0">
              <span class="absolute inset-0" aria-hidden="true"></span>
              <p class="text-sm font-medium text-foreground">Manage Clients</p>
              <p class="text-sm text-muted-foreground truncate">View and manage desktop clients with live connection status</p>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end