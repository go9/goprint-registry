defmodule GoprintRegistryWeb.DashboardLive do
  use GoprintRegistryWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-foreground">Dashboard</h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Welcome to your GoPrint dashboard
          </p>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Connected Printers -->
        <div class="bg-card overflow-hidden shadow rounded-lg border border-base">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-muted-foreground truncate">
              Connected Printers
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-foreground">
              0
            </dd>
          </div>
        </div>

        <!-- Print Jobs Today -->
        <div class="bg-card overflow-hidden shadow rounded-lg border border-base">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-muted-foreground truncate">
              Print Jobs Today
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-foreground">
              0
            </dd>
          </div>
        </div>

        <!-- Active Sessions -->
        <div class="bg-card overflow-hidden shadow rounded-lg border border-base">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-muted-foreground truncate">
              Active Sessions
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-foreground">
              0
            </dd>
          </div>
        </div>
      </div>

      <!-- Recent Activity -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-foreground">Recent Activity</h2>
        <div class="mt-4 bg-card shadow overflow-hidden sm:rounded-md border border-base">
          <div class="px-4 py-5 sm:p-6">
            <p class="text-sm text-muted-foreground">
              No recent activity to display
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {GoprintRegistryWeb.Layouts, :app}}
  end
end