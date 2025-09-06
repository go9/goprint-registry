defmodule GoprintRegistryWeb.DashboardLive do
  use GoprintRegistryWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Dashboard</h1>
          <p class="mt-2 text-sm text-gray-700 dark:text-gray-300">
            Welcome to your GoPrint Registry dashboard
          </p>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Connected Printers -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
              Connected Printers
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
              0
            </dd>
          </div>
        </div>

        <!-- Print Jobs Today -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
              Print Jobs Today
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
              0
            </dd>
          </div>
        </div>

        <!-- Active Sessions -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
              Active Sessions
            </dt>
            <dd class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white">
              0
            </dd>
          </div>
        </div>
      </div>

      <!-- Recent Activity -->
      <div class="mt-8">
        <h2 class="text-lg font-medium text-gray-900 dark:text-white">Recent Activity</h2>
        <div class="mt-4 bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:p-6">
            <p class="text-sm text-gray-500 dark:text-gray-400">
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