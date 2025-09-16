defmodule GoprintRegistryWeb.ClientController do
  use GoprintRegistryWeb, :controller
  
  alias GoprintRegistry.{Clients, ConnectionManager}
  alias GoprintRegistry.Services.{ClientRegistration, PrinterService}
  require Logger

  # POST /api/clients/register
  def register(conn, params) do
    ip_address = get_client_ip(conn)
    
    case ClientRegistration.register(params, ip_address) do
      {:ok, response_data} ->
        status = if response_data[:already_registered], do: :ok, else: :created
        
        conn
        |> put_status(status)
        |> json(response_data)
      
      {:error, :bad_request, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: message})
    end
  end

  # POST /api/clients/login
  def login(conn, %{"client_id" => client_id, "client_secret" => client_secret} = params) do
    ip_address = get_client_ip(conn)
    
    case ClientRegistration.authenticate(client_id, client_secret, params, ip_address) do
      {:ok, response_data} ->
        json(conn, response_data)
      
      {:error, :unauthorized, message} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: message})
    end
  end
  
  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "client_id and client_secret are required"})
  end

  # GET /api/clients/verify/:client_id
  def verify(conn, %{"client_id" => client_id}) do
    case Clients.get_client(client_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Invalid client ID"})
      
      client ->
        conn
        |> json(%{
          success: true,
          client: %{
            id: client.id,
            api_name: client.api_name,
            machine_name: client.machine_name
          }
        })
    end
  end

  # POST /api/clients/heartbeat
  def heartbeat(conn, %{"client_id" => client_id} = params) do
    ip_address = params["ip"] || get_client_ip(conn)
    
    case Clients.update_heartbeat(client_id) do
      {:ok, _client} ->
        if ip_address, do: Clients.log_ip_address(client_id, ip_address)
        json(conn, %{success: true})
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Invalid client ID"})
      
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Heartbeat failed"})
    end
  end

  # GET /api/clients/:client_id/printers
  def get_printers(conn, %{"client_id" => client_id}) do
    case PrinterService.get_printers(client_id) do
      {:ok, response} ->
        json(conn, response)
      
      {:error, :not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: message})
      
      {:error, :service_unavailable, message} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{success: false, error: message})
      
      {:error, :request_timeout, message} ->
        conn
        |> put_status(:request_timeout)
        |> json(%{success: false, error: message})
    end
  end

  # GET /api/clients/:client_id/printers/:printer_id/capabilities
  def get_printer_capabilities(conn, %{"client_id" => client_id, "printer_id" => printer_id}) do
    case PrinterService.get_printer_capabilities(client_id, printer_id) do
      {:ok, capabilities} ->
        json(conn, %{success: true, capabilities: capabilities})
      
      {:error, :not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: message})
      
      {:error, :service_unavailable, message} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{success: false, error: message})
      
      {:error, :request_timeout, message} ->
        conn
        |> put_status(:request_timeout)
        |> json(%{success: false, error: message})
    end
  end

  # GET /api/clients
  def list_user_clients(conn, _params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        clients = Clients.list_user_clients(user.id)
        
        client_data = Enum.map(clients, fn client ->
          %{
            id: client.id,
            api_name: client.api_name,
            status: get_client_status(client),
            last_connected_at: client.last_connected_at,
            registered_at: client.registered_at,
            operating_system: client.operating_system,
            app_version: client.app_version,
            printer_count: length(Map.get(client, :printers, []))
          }
        end)
        
        json(conn, client_data)
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end

  # GET /api/clients/:client_id
  def get_client_details(conn, %{"client_id" => client_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        if Clients.user_has_access?(user.id, client_id) do
          case Clients.get_client(client_id) do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{success: false, error: "Client not found"})
              
            client ->
              # Try to get printers from WebSocket connection
              printers = case ConnectionManager.get_client(client_id) do
                {:ok, %{printers: printers}} -> printers
                _ -> []
              end
              
              # Get print job statistics
              stats = GoprintRegistry.PrintJobs.get_client_statistics(client_id)
              
              client_detail = %{
                id: client.id,
                api_name: client.api_name,
                status: get_client_status(client),
                last_connected_at: client.last_connected_at,
                registered_at: client.registered_at,
                operating_system: client.operating_system,
                app_version: client.app_version,
                printers: printers,
                statistics: %{
                  total_jobs: stats.total_jobs,
                  completed_jobs: stats.completed_jobs,
                  failed_jobs: stats.failed_jobs,
                  pages_printed: stats.pages_printed || 0
                }
              }
              
              json(conn, client_detail)
          end
        else
          conn
          |> put_status(:forbidden)
          |> json(%{success: false, error: "Access denied"})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end

  # POST /api/clients/subscribe
  def subscribe(conn, %{"client_id" => client_id}) do
    current_scope = conn.assigns.current_scope
    
    with %{user: user} <- current_scope || %{},
         {:ok, _cu} <- Clients.associate_user_with_client(user.id, String.trim(client_id)) do
      json(conn, %{success: true, client_id: client_id})
    else
      {:error, :invalid_client_id} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Invalid client ID"})
      
      {:error, :already_associated} ->
        conn
        |> put_status(:conflict)
        |> json(%{success: false, error: "Already subscribed to this client"})
      
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Failed to subscribe to client"})
    end
  end

  # DELETE /api/clients/:client_id/unsubscribe
  def unsubscribe_client(conn, %{"client_id" => client_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case Clients.unassociate_user_from_client(user.id, client_id) do
          {:ok, _} ->
            json(conn, %{success: true, message: "Successfully unsubscribed from client"})
            
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{success: false, error: "Client association not found"})
            
          _ ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "Failed to unsubscribe"})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end

  # POST /api/clients/:client_id/test-print
  def test_print(conn, %{"id" => client_id} = params) do
    case PrinterService.send_test_print(client_id, params["printer_id"], params) do
      {:ok, job_id} ->
        json(conn, %{success: true, job_id: job_id, message: "Test print sent"})
      
      {:error, :not_found, message} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: message})
      
      {:error, :service_unavailable, message} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{success: false, error: message})
    end
  end

  # Private functions

  defp get_client_ip(conn) do
    # Check X-Forwarded-For header first (for proxied requests)
    forwarded = get_req_header(conn, "x-forwarded-for")
    
    case forwarded do
      [ips | _] -> 
        # Take the first IP if multiple are present
        ips |> String.split(",") |> List.first() |> String.trim()
      _ ->
        # Fall back to remote_ip
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          {a, b, c, d, e, f, g, h} -> 
            # IPv6 address
            "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:" <>
            "#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:" <>
            "#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:" <>
            "#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"
          _ -> nil
        end
    end
  end

  defp get_client_status(client) do
    # Check if client is connected via WebSocket
    ws_connections = ConnectionManager.list_connections()
    is_connected = Enum.any?(ws_connections, fn {id, _} -> id == client.id end)
    
    if is_connected do
      "connected"
    else
      # Check last connection time
      case client.last_connected_at do
        nil -> "disconnected"
        last_connected ->
          # If connected in last 5 minutes, show as recently connected
          diff = DateTime.diff(DateTime.utc_now(), last_connected, :minute)
          if diff <= 5, do: "disconnected", else: "disconnected"
      end
    end
  end
end