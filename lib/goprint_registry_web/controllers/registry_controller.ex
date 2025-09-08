defmodule GoprintRegistryWeb.RegistryController do
  use GoprintRegistryWeb, :controller
  alias GoprintRegistry.{Clients, ConnectionManager}

  def status(conn, _params) do
    json(conn, %{
      status: "healthy",
      service: "goprint_registry",
      version: "1.0.0",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
  
  def debug_connections(conn, _params) do
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
    
    # Compare DB status with actual WebSocket status
    client_comparison = Enum.map(all_clients, fn client ->
      ws_connected = Enum.any?(websocket_connections, fn {id, _} -> id == client.id end)
      
      %{
        client_id: client.id,
        api_name: client.api_name,
        db_status: client.status,
        actual_ws_connected: ws_connected,
        last_connected_at: client.last_connected_at,
        status_mismatch: client.status == "connected" && !ws_connected,
        should_be: if(ws_connected, do: "connected", else: "disconnected")
      }
    end)
    
    # Find mismatches
    mismatches = Enum.filter(client_comparison, & &1.status_mismatch)
    
    json(conn, %{
      success: true,
      summary: %{
        total_clients_in_db: length(all_clients),
        active_websockets: length(websocket_connections),
        db_says_connected: Enum.count(all_clients, & &1.status == "connected"),
        mismatches: length(mismatches)
      },
      active_websocket_connections: ws_details,
      all_clients: client_comparison,
      problems: mismatches,
      note: "Only 'active_websocket_connections' shows real connections. DB status can be wrong."
    })
  end
end