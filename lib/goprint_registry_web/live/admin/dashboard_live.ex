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
          <h1 class="text-3xl font-bold leading-6 text-gray-900">Admin Dashboard</h1>
          <p class="mt-2 text-sm text-gray-700">
            Overview of system statistics and quick access to administrative functions.
          </p>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Users Card -->
        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                  <dd class="text-3xl font-semibold text-gray-900"><%= @user_count %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-5 py-3">
            <div class="text-sm">
              <.link navigate={~p"/admin/users"} class="font-medium text-blue-600 hover:text-blue-500">
                View all users →
              </.link>
            </div>
          </div>
        </div>

        <!-- Clients Card -->
        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25m18 0A2.25 2.25 0 0018.75 3H5.25A2.25 2.25 0 003 5.25m18 0V12a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 12V5.25" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Clients</dt>
                  <dd class="text-3xl font-semibold text-gray-900"><%= @client_count %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-5 py-3">
            <div class="text-sm">
              <.link navigate={~p"/admin/clients"} class="font-medium text-blue-600 hover:text-blue-500">
                View all clients →
              </.link>
            </div>
          </div>
        </div>

        <!-- Active Clients Card -->
        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9.348 14.651a3.75 3.75 0 010-5.303m5.304 0a3.75 3.75 0 010 5.303m-7.425 2.122a6.75 6.75 0 010-9.546m9.546 0a6.75 6.75 0 010 9.546M5.106 18.894c-3.808-3.808-3.808-9.98 0-13.789m13.788 0c3.808 3.808 3.808 9.981 0 13.79M12 12h.008v.007H12V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Active Clients</dt>
                  <dd class="text-3xl font-semibold text-gray-900"><%= @active_clients %></dd>
                </dl>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-5 py-3">
            <div class="text-sm text-gray-500">
              Connected in last 5 minutes
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-gray-900">Quick Actions</h2>
        <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.link
            navigate={~p"/admin/users"}
            class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500"
          >
            <div class="flex-1 min-w-0">
              <span class="absolute inset-0" aria-hidden="true"></span>
              <p class="text-sm font-medium text-gray-900">Manage Users</p>
              <p class="text-sm text-gray-500 truncate">View and edit user accounts</p>
            </div>
          </.link>

          <.link
            navigate={~p"/admin/clients"}
            class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500"
          >
            <div class="flex-1 min-w-0">
              <span class="absolute inset-0" aria-hidden="true"></span>
              <p class="text-sm font-medium text-gray-900">Manage Clients</p>
              <p class="text-sm text-gray-500 truncate">View and manage desktop clients with live connection status</p>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end