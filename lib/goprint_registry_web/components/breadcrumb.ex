defmodule GoprintRegistryWeb.Components.Layout.Breadcrumb do
  use Phoenix.Component

  @doc """
  Renders breadcrumbs using Flowbite styling with dark mode support.

  ## Examples

      <.breadcrumb items={[
        %{label: "Home", path: "/"},
        %{label: "Products", path: "/products"},
        %{label: "Show", path: nil}
      ]} />
      
      <.breadcrumb>
        <:item label="Home" path="/" />
        <:item label="Products" path="/products" />
        <:item label="Show" />
      </.breadcrumb>
  """
  attr :items, :list, default: []

  slot :item do
    attr :label, :string, required: true
    attr :path, :string
  end

  def breadcrumb(assigns) do
    # Convert slot items to list format for consistent handling
    items =
      if assigns.items != [] do
        assigns.items
      else
        Enum.map(assigns.item, fn item ->
          %{label: item.label, path: Map.get(item, :path)}
        end)
      end

    assigns = assign(assigns, :processed_items, items)

    ~H"""
    <nav class="flex" aria-label="Breadcrumb">
      <ol class="inline-flex items-center space-x-1 md:space-x-2">
        <%= for {item, index} <- Enum.with_index(@processed_items) do %>
          <%= if index == 0 do %>
            <!-- Home/First Item -->
            <li class="inline-flex items-center">
              <%= if item.path && index < length(@processed_items) - 1 do %>
                <.link
                  navigate={item.path}
                  class="inline-flex items-center text-sm font-medium text-gray-600 hover:text-primary-600 dark:text-gray-400 dark:hover:text-white transition-colors duration-200"
                >
                  <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
                  </svg>
                  {item.label}
                </.link>
              <% else %>
                <span class="inline-flex items-center text-sm font-medium text-gray-500 dark:text-gray-400">
                  <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
                  </svg>
                  {item.label}
                </span>
              <% end %>
            </li>
          <% else %>
            <!-- Separator and Item -->
            <li>
              <div class="flex items-center">
                <svg class="w-3 h-3 mx-2 text-gray-400" fill="none" viewBox="0 0 6 10">
                  <path
                    stroke="currentColor"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="m1 9 4-4-4-4"
                  />
                </svg>
                <%= if item.path && index < length(@processed_items) - 1 do %>
                  <.link
                    navigate={item.path}
                    class="ml-1 text-sm font-medium text-gray-600 hover:text-primary-600 md:ml-2 dark:text-gray-400 dark:hover:text-white transition-colors duration-200"
                  >
                    {item.label}
                  </.link>
                <% else %>
                  <span class="ml-1 text-sm font-medium text-gray-500 md:ml-2 dark:text-gray-400">
                    {item.label}
                  </span>
                <% end %>
              </div>
            </li>
          <% end %>
        <% end %>
      </ol>
    </nav>
    """
  end

  @doc """
  Helper function to build breadcrumb items for common patterns.

  ## Examples

      build_breadcrumbs([
        {"Home", ~p"/"},
        {"Products", ~p"/products"},
        {"Edit Product", nil}
      ])
  """
  def build_breadcrumbs(items) when is_list(items) do
    Enum.map(items, fn
      {label, path} -> %{label: label, path: path}
      %{label: _label} = item -> item
    end)
  end
end
