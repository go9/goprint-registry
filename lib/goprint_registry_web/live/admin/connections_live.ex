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
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold leading-6 text-foreground">Connection Debug Dashboard</h1>
          <p class="mt-2 text-sm text-muted-foreground">Real-time WebSocket Connection Status</p>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-lg font-semibold mb-4 text-foreground">Summary</h2>
        <div class="grid grid-cols-2 gap-4">
          <div class="bg-card rounded-lg p-4 shadow border border-base">
            <div class="text-sm text-muted-foreground">Total Registered Clients</div>
            <div class="text-2xl font-bold text-foreground"><%= @summary.total_clients_in_db %></div>
          </div>
          <div class="bg-card rounded-lg p-4 shadow border border-base">
            <div class="text-sm text-muted-foreground">Active WebSocket Connections</div>
            <div class="text-2xl font-bold text-success"><%= @summary.active_websockets %></div>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-lg font-semibold mb-4 text-foreground">Active WebSocket Connections</h2>
        <%= if @websocket_connections == [] do %>
          <div class="bg-muted rounded-lg p-8 text-center text-muted-foreground">
            No active WebSocket connections
          </div>
        <% else %>
          <div class="overflow-hidden shadow ring-1 ring-black/5 dark:ring-white/10 sm:rounded-lg">
            <table class="min-w-full divide-y divide-base">
              <thead class="bg-muted/50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Client ID
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Connected At
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Last Heartbeat
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Printers
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    Process
                  </th>
                </tr>
              </thead>
              <tbody class="bg-card divide-y divide-base">
                <%= for conn <- @websocket_connections do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="font-mono text-sm text-foreground"><%= conn.client_id %></span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= format_datetime(conn.connected_at) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.badge color={heartbeat_color(conn.last_heartbeat_ms_ago)}>
                        <%= format_ms_ago(conn.last_heartbeat_ms_ago) %>
                      </.badge>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                      <%= conn.printers %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.badge color={if conn.process_alive, do: "success", else: "danger"}>
                        <%= if conn.process_alive, do: "Alive", else: "Dead" %>
                      </.badge>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <div class="mt-8">
        <h2 class="text-lg font-semibold mb-4 text-foreground">All Registered Clients</h2>
        <div class="overflow-hidden shadow ring-1 ring-black/5 dark:ring-white/10 sm:rounded-lg">
          <table class="min-w-full divide-y divide-base">
            <thead class="bg-muted/50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Client
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  WebSocket Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                  Last Connected
                </th>
              </tr>
            </thead>
            <tbody class="bg-card divide-y divide-base">
              <%= for client <- @all_clients do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div>
                      <div class="font-mono text-sm text-foreground"><%= client.client_id %></div>
                      <div class="text-sm text-muted-foreground"><%= client.api_name %></div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <.badge color={if client.actual_ws_connected, do: "success", else: "info"}>
                      <%= if client.actual_ws_connected, do: "Connected", else: "Disconnected" %>
                    </.badge>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                    <%= format_datetime(client.last_connected_at) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-4 text-sm text-muted-foreground">
        <p>
          <strong class="text-foreground">Note:</strong> This page shows real-time WebSocket connections.
          Auto-refreshes every 2 seconds.
        </p>
      </div>
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
  
  defp heartbeat_color(ms) when ms < 10_000, do: "success"
  defp heartbeat_color(ms) when ms < 30_000, do: "warning"
  defp heartbeat_color(_), do: "danger"
  
  # Removed unused status_class function
end