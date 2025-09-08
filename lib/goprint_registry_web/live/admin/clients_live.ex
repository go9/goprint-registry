defmodule GoprintRegistryWeb.Admin.ClientsLive do
  use GoprintRegistryWeb, :live_view
  alias GoprintRegistry.{Clients, ConnectionManager}
  alias GoprintRegistry.Clients.Client

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Refresh connection status every 2 seconds
      :timer.send_interval(2000, self(), :refresh_connections)
    end
    
    {:ok,
     socket
     |> assign(:page_title, "Admin - Clients")
     |> stream(:clients, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Flop.validate(params, for: Client) do
      {:ok, flop} ->
        {clients, meta} = Clients.list_clients_with_flop(flop)
        
        # Get active WebSocket connections
        ws_connections = ConnectionManager.list_connections()
        ws_client_ids = Enum.map(ws_connections, fn {client_id, _} -> client_id end)
        
        # Update status based on actual WebSocket connections
        clients_with_ws = Enum.map(clients, fn client ->
          Map.from_struct(client)
          |> Map.put(:status, if(client.id in ws_client_ids, do: "connected", else: "disconnected"))
          |> Map.put(:ws_connected, client.id in ws_client_ids)
        end)
        
        {:noreply,
         socket
         |> stream(:clients, clients_with_ws, reset: true)
         |> assign(:meta, meta)}
      
      {:error, _meta} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/clients")}
    end
  end

  @impl true
  def handle_info(:refresh_connections, socket) do
    # Just refresh the clients directly
    {clients, meta} = list_clients(socket.assigns.meta.flop)
    
    socket = 
      socket
      |> stream(:clients, clients, reset: true)
      |> assign(:meta, meta)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/admin/clients?#{params}")}
  end

  @impl true
  def handle_event("delete-client", %{"id" => id}, socket) do
    client = Clients.get_client!(id)
    
    case Clients.delete_client(client) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client deleted successfully")
         |> push_navigate(to: ~p"/admin/clients")}
      
      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete client")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold leading-6 text-gray-900">Clients</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage all desktop clients registered in the system.
          </p>
        </div>
      </div>

      <!-- Search and Filters -->
      <div class="mt-6">
        <.form :let={_f} for={%{}} phx-change="update-filter" phx-submit="update-filter">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label for="search" class="block text-sm font-medium text-gray-700">Search</label>
              <div class="mt-1">
                <input
                  type="text"
                  name="q"
                  id="search"
                  value={@meta.flop.filters[:q] || ""}
                  placeholder="Search by name or MAC address..."
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              </div>
            </div>
            
            <div>
              <label for="status_filter" class="block text-sm font-medium text-gray-700">Status</label>
              <div class="mt-1">
                <select
                  name="status"
                  id="status_filter"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                >
                  <option value="">All Clients</option>
                  <option value="active" selected={@meta.flop.filters[:status] == "active"}>Active</option>
                  <option value="inactive" selected={@meta.flop.filters[:status] == "inactive"}>Inactive</option>
                </select>
              </div>
            </div>
          </div>
        </.form>
      </div>

      <!-- Clients Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      MAC Address
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      OS
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Last Connected
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Registered
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr :for={{id, client} <- @streams.clients} id={id}>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      <%= client.api_name || "Unknown" %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <code class="text-xs bg-gray-100 px-1 py-0.5 rounded">
                        <%= client.mac_address || "-" %>
                      </code>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= if is_client_active?(client) do %>
                        <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                          <svg class="mr-1.5 h-2 w-2 text-green-400" fill="currentColor" viewBox="0 0 8 8">
                            <circle cx="4" cy="4" r="3" />
                          </svg>
                          Active
                        </span>
                      <% else %>
                        <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
                          <svg class="mr-1.5 h-2 w-2 text-gray-400" fill="currentColor" viewBox="0 0 8 8">
                            <circle cx="4" cy="4" r="3" />
                          </svg>
                          Inactive
                        </span>
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= client.operating_system || "-" %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= if client.last_connected_at do %>
                        <%= format_relative_time(client.last_connected_at) %>
                      <% else %>
                        Never
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= Calendar.strftime(client.inserted_at, "%b %d, %Y") %>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <button
                        phx-click="delete-client"
                        phx-value-id={client.id}
                        data-confirm="Are you sure you want to delete this client?"
                        class="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div class="mt-4">
        <Flop.Phoenix.pagination meta={@meta} path={~p"/admin/clients"} />
      </div>
    </div>
    """
  end

  defp is_client_active?(client) do
    client.last_connected_at &&
      DateTime.diff(DateTime.utc_now(), client.last_connected_at, :second) < 300
  end

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end