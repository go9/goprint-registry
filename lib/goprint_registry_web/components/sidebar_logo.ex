defmodule GoprintRegistryWeb.Components.Layout.SidebarLogo do
  use GoprintRegistryWeb, :html

  def sidebar_logo(assigns) do
    ~H"""
    <.link
      navigate="/dashboard"
      class="flex items-center space-x-3 hover:opacity-80 transition-opacity"
    >
      <div class="p-2 bg-primary-600 rounded-lg">
        <svg class="w-8 h-8 text-white" viewBox="0 0 24 24" fill="currentColor">
          <path d="M20 6h-2.18c.11-.31.18-.65.18-1a2.996 2.996 0 0 0-5.5-1.65l-.5.67-.5-.68C10.96 2.54 10.05 2 9 2 7.34 2 6 3.34 6 5c0 .35.07.69.18 1H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-5-2c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zM9 4c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm11 15H4v-2h16v2zm0-5H4V8h5.08L7 10.83 8.62 12 11 8.76l1-1.36 1 1.36L15.38 12 17 10.83 14.92 8H20v6z" />
        </svg>
      </div>
      <div>
        <h1 class="text-xl font-bold">Enventory</h1>
        <p class="text-xs text-gray-500 dark:text-gray-400">Multi-Channel Commerce</p>
      </div>
    </.link>
    """
  end
end
