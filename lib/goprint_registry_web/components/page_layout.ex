defmodule GoprintRegistryWeb.Components.Layout.PageLayout do
  use Phoenix.Component
  import GoprintRegistryWeb.Components.Layout.Breadcrumb

  attr :breadcrumbs, :list, default: []
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :container, :boolean, default: true
  slot :actions
  slot :inner_block, required: true

  def page_layout(assigns) do
    ~H"""
    <!-- Unified Container with Header and Content -->
    <div class="bg-white dark:bg-gray-800">
      <div class={container_classes(@container)}>
        <!-- Page Header with Breadcrumbs and Actions -->
        <div class="py-4">
          <!-- Breadcrumbs Section -->
          <%= if @breadcrumbs && length(@breadcrumbs) > 0 do %>
            <div class="mb-3">
              <.breadcrumb items={@breadcrumbs} />
            </div>
          <% end %>
          
    <!-- Title and Actions Section -->
          <%= if @title do %>
            <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
              <!-- Title and Description -->
              <div class="min-w-0 flex-1">
                <h1 class="text-3xl font-bold font-heading text-gray-900 dark:text-white tracking-tight">
                  {@title}
                </h1>
                <%= if @description do %>
                  <p class="mt-2 text-base text-gray-600 dark:text-gray-300 leading-6">
                    {@description}
                  </p>
                <% end %>
              </div>
              
    <!-- Actions -->
              <%= if @actions != [] do %>
                <div class="flex items-center gap-3 sm:ml-6">
                  {render_slot(@actions)}
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Content Separator -->
        <%= if @title || (@breadcrumbs && length(@breadcrumbs) > 0) do %>
          <div class="border-t border-gray-200 dark:border-gray-700"></div>
        <% end %>
        
    <!-- Main Content -->
        <div class="py-4">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  defp container_classes(true), do: "mx-auto max-w-6xl px-4"
  defp container_classes(false), do: "px-4"
end
