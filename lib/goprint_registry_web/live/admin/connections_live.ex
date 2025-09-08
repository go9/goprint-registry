defmodule GoprintRegistryWeb.Admin.ConnectionsLive do
  use GoprintRegistryWeb, :live_view
  alias GoprintRegistry.{ConnectionManager, Clients}
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(2000, self(), :refresh)
    end
    
    socket = load_connections(socket)
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_connections(socket)}
  end
  
  defp load_connections(socket) do
    # Get ACTUAL WebSocket connections from ETS
    websocket_connections = ConnectionManager.list_connections()
    
    # Get all clients from database
    all_clients = Clients.list_clients()
    
    # Build detailed connection info
    ws_details = Enum.map(websocket_connections, fn {client_id, data} ->
      %{
        client_id: client_id,
        connected_via: "websocket",
        connected_at: data.connected_at,
        last_heartbeat_ms_ago: System.system_time(:millisecond) - data.last_heartbeat,
        printers: length(data.printers || []),
        process_alive: Process.alive?(data.pid)
      }
    end)
    
    # Compare all clients with actual WebSocket status
    client_comparison = Enum.map(all_clients, fn client ->
      ws_connected = Enum.any?(websocket_connections, fn {id, _} -> id == client.id end)
      
      %{
        client_id: client.id,
        api_name: client.api_name,
        actual_ws_connected: ws_connected,
        last_connected_at: client.last_connected_at
      }
    end)
    
    # Not needed anymore since we're not showing DB status
    mismatches = []
    
    socket
    |> assign(:websocket_connections, ws_details)
    |> assign(:all_clients, client_comparison)
    |> assign(:mismatches, mismatches)
    |> assign(:summary, %{
      total_clients_in_db: length(all_clients),
      active_websockets: length(websocket_connections),
      mismatches: 0
    })
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Connection Debug Dashboard
      <:subtitle>Real-time WebSocket Connection Status</:subtitle>
    </.header>
    
    <div class="mt-8">
      <h2 class="text-lg font-semibold mb-4">Summary</h2>
      <div class="grid grid-cols-2 gap-4">
        <div class="bg-white rounded-lg p-4 shadow">
          <div class="text-sm text-gray-500">Total Registered Clients</div>
          <div class="text-2xl font-bold"><%= @summary.total_clients_in_db %></div>
        </div>
        <div class="bg-white rounded-lg p-4 shadow">
          <div class="text-sm text-gray-500">Active WebSocket Connections</div>
          <div class="text-2xl font-bold text-green-600"><%= @summary.active_websockets %></div>
        </div>
      </div>
    </div>
    
    <!-- Remove mismatches section since DB status is not reliable -->
    <div class="hidden">
      <div class={"text-2xl font-bold #{if @summary.mismatches > 0, do: "text-red-600", else: "text-green-600"}"}>
            <%= @summary.mismatches %>
          </div>
    </div>
    
    <%= if false do %>
      <div class="mt-8 bg-red-50 border border-red-200 rounded-lg p-4">
        <h3 class="text-lg font-semibold text-red-800 mb-2">⚠️ Status Mismatches</h3>
        <p class="text-sm text-red-700 mb-4">
          These clients show as "connected" in the database but have no active WebSocket connection:
        </p>
        <div class="space-y-2">
          <%= for mismatch <- @mismatches do %>
            <div class="bg-white rounded p-3 flex justify-between items-center">
              <div>
                <span class="font-mono text-sm"><%= mismatch.client_id %></span>
                <span class="ml-2 text-gray-600"><%= mismatch.api_name %></span>
              </div>
              <div class="text-sm">
                Last seen: <%= format_datetime(mismatch.last_connected_at) %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <div class="mt-8">
      <h2 class="text-lg font-semibold mb-4">Active WebSocket Connections</h2>
      <%= if @websocket_connections == [] do %>
        <div class="bg-gray-50 rounded-lg p-8 text-center text-gray-500">
          No active WebSocket connections
        </div>
      <% else %>
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Client ID
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Connected At
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Last Heartbeat
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Printers
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Process
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for conn <- @websocket_connections do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="font-mono text-sm"><%= conn.client_id %></span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= format_datetime(conn.connected_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{heartbeat_class(conn.last_heartbeat_ms_ago)}"}>
                      <%= format_ms_ago(conn.last_heartbeat_ms_ago) %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= conn.printers %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if conn.process_alive, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      <%= if conn.process_alive, do: "Alive", else: "Dead" %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    
    <div class="mt-8">
      <h2 class="text-lg font-semibold mb-4">All Registered Clients</h2>
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Client
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                WebSocket Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Last Connected
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for client <- @all_clients do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div>
                    <div class="font-mono text-sm"><%= client.client_id %></div>
                    <div class="text-sm text-gray-500"><%= client.api_name %></div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if client.actual_ws_connected, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                    <%= if client.actual_ws_connected, do: "Connected", else: "Disconnected" %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= format_datetime(client.last_connected_at) %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    
    <div class="mt-4 text-sm text-gray-500">
      <p>
        <strong>Note:</strong> This page shows real-time WebSocket connections.
        Auto-refreshes every 2 seconds.
      </p>
    </div>
    """
  end
  
  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
  
  defp format_ms_ago(ms) when ms < 1000, do: "#{ms}ms ago"
  defp format_ms_ago(ms) when ms < 60_000, do: "#{div(ms, 1000)}s ago"
  defp format_ms_ago(ms), do: "#{div(ms, 60_000)}m ago"
  
  defp heartbeat_class(ms) when ms < 10_000, do: "bg-green-100 text-green-800"
  defp heartbeat_class(ms) when ms < 30_000, do: "bg-yellow-100 text-yellow-800"
  defp heartbeat_class(_), do: "bg-red-100 text-red-800"
  
  # Removed unused status_class function
end