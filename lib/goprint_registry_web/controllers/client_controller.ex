defmodule GoprintRegistryWeb.ClientController do
  use GoprintRegistryWeb, :controller
  alias GoprintRegistry.{Clients, Accounts}
  require Logger

  # POST /api/clients/register
  # Called by desktop client to self-register when first launched
  def register(conn, params) do
    # Get client IP address from connection
    ip_address = get_client_ip(conn)
    
    mac_address =
      params["mac_address"] || params["mac"] || params["macAddress"]
      |> case do
        nil -> nil
        v -> String.trim(to_string(v))
      end
    operating_system = params["operating_system"] || params["os"] || params["os_name"]
    app_version = params["app_version"] || params["version"]
    fallback_id = params["client_id"] || Ecto.UUID.generate()
    mac_address = if mac_address in [nil, ""], do: "unknown:" <> fallback_id, else: mac_address

    # Generate a secure client secret
    client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    
    attrs = %{
      api_name: params["api_name"] || "Desktop Client",
      mac_address: mac_address,
      operating_system: operating_system,
      app_version: app_version,
      client_secret_hash: Bcrypt.hash_pwd_salt(client_secret)
    }

    Logger.info("client_register", attrs: Map.drop(attrs, [:client_secret_hash]), ip: ip_address)

    case Clients.create_client(attrs, ip_address) do
      {:ok, client} ->
        # Optionally auto-associate to a user if a valid user_token is provided
        _ =
          case params["user_token"] do
            nil -> :ok
            token ->
              case Accounts.get_user_by_session_token(token) do
                {user, _} -> Clients.associate_user_with_client(user.id, client.id)
                _ -> :ok
              end
          end

        # Generate WebSocket token for immediate connection
        ws_token = Phoenix.Token.sign(GoprintRegistryWeb.Endpoint, "ws_client", %{
          client_id: client.id,
          authenticated_at: DateTime.utc_now()
        })
        
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          client_id: client.id,  # Return the UUID as client_id
          client_secret: client_secret,  # Return the secret ONLY during registration
          ws_token: ws_token,  # Include ws_token so client can connect immediately
          registered_at: client.registered_at
        })
      
      {:error, changeset} ->
        # Check if it's a unique constraint error (client already registered)
        if Keyword.has_key?(changeset.errors, :mac_address) do
          # Machine already registered, update it with new secret
          client = Clients.get_client_by_mac_address(mac_address)
          if client do
            # Generate a new client secret for this session
            new_client_secret = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
            
            # Update the client with new secret and metadata
            update_attrs = %{
              client_secret_hash: Bcrypt.hash_pwd_salt(new_client_secret),
              operating_system: operating_system,
              app_version: app_version
            }
            
            {:ok, updated_client} = Clients.update_client(client, update_attrs)
            
            # Log the IP address for existing client
            if ip_address, do: Clients.log_ip_address(updated_client.id, ip_address)
            # Attempt association if user_token provided
            _ =
              case params["user_token"] do
                nil -> :ok
                token ->
                  case Accounts.get_user_by_session_token(token) do
                    {user, _} -> Clients.associate_user_with_client(user.id, updated_client.id)
                    _ -> :ok
                  end
              end
            # Generate WebSocket token for immediate connection
            ws_token = Phoenix.Token.sign(GoprintRegistryWeb.Endpoint, "ws_client", %{
              client_id: updated_client.id,
              authenticated_at: DateTime.utc_now()
            })
            
            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              already_registered: true,
              client_id: updated_client.id,
              client_secret: new_client_secret,  # Return the NEW secret
              ws_token: ws_token,  # Include ws_token so client can connect immediately
              registered_at: updated_client.registered_at
            })
          else
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "Invalid registration"})
          end
        else
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: "Registration failed", details: inspect(changeset.errors)})
        end
    end
  end

  # GET /api/clients/verify/:client_id
  # Called to verify client ID is valid
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
  
  # Extract client IP address from connection
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

  # POST /api/clients/login
  # Called by desktop client on startup to obtain a short-lived WS token
  # Accepts: client_id, client_secret (required), operating_system, app_version
  def login(conn, %{"client_id" => client_id, "client_secret" => client_secret} = params) do
    os = params["operating_system"] || params["os"]
    app_version = params["app_version"] || params["version"]
    ip_address = get_client_ip(conn)

    case Clients.get_client(client_id) do
      nil ->
        # Invalid client ID
        conn 
        |> put_status(:unauthorized) 
        |> json(%{success: false, error: "Invalid credentials"})
        
      %{client_secret_hash: nil} ->
        # Legacy client without secret - needs to re-register
        conn 
        |> put_status(:unauthorized) 
        |> json(%{success: false, error: "Client needs to re-register for security update"})
        
      client ->
        # Verify the client secret
        if Bcrypt.verify_pass(client_secret, client.client_secret_hash) do
          # Update metadata if provided
          if os || app_version do
            update_attrs = %{}
            |> then(fn m -> if os, do: Map.put(m, :operating_system, os), else: m end)
            |> then(fn m -> if app_version, do: Map.put(m, :app_version, app_version), else: m end)
            _ = Clients.update_client(client, update_attrs)
          end
          
          # Log IP address
          if ip_address, do: Clients.log_ip_address(client_id, ip_address)
          
          # Generate WebSocket token (include client_id only, not the secret)
          token = Phoenix.Token.sign(GoprintRegistryWeb.Endpoint, "ws_client", %{
            client_id: client.id,
            authenticated_at: DateTime.utc_now()
          })
          
          json(conn, %{
            success: true, 
            ws_token: token, 
            client_id: client.id,
            expires_in: 600  # 10 minutes
          })
        else
          # Invalid secret
          conn 
          |> put_status(:unauthorized) 
          |> json(%{success: false, error: "Invalid credentials"})
        end
    end
  end
  
  def login(conn, _params) do
    conn 
    |> put_status(:bad_request) 
    |> json(%{success: false, error: "client_id and client_secret are required"})
  end

  # POST /clients/subscribe
  # Associates the currently authenticated user with a client id
  # This is used by developers (users of GoCloud) to subscribe to an end-user client
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

  # POST /api/clients/heartbeat
  # Lightweight heartbeat from desktop agent; updates last_connected_at and logs IP
  # NOTE: This does NOT set status to "connected" - only WebSocket connections do that
  def heartbeat(conn, %{"client_id" => client_id} = params) do
    ip_address = params["ip"] || get_client_ip(conn)
    
    case Clients.update_heartbeat(client_id) do
      {:ok, _client} ->
        if ip_address, do: Clients.log_ip_address(client_id, ip_address)
        json(conn, %{success: true})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Invalid client ID"})
      _ ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Heartbeat failed"})
    end
  end
  
  # GET /api/clients/:client_id/printers
  # Fetch printer list on-demand from a connected desktop client
  def get_printers(conn, %{"client_id" => client_id}) do
    # Check if client exists
    case Clients.get_client(client_id) do
      nil ->
        conn 
        |> put_status(:not_found) 
        |> json(%{success: false, error: "Client not found"})
      
      _client ->
        # Check if client is connected via WebSocket
        case GoprintRegistry.ConnectionManager.get_client(client_id) do
          {:ok, %{printers: printers}} ->
            # Return cached printers from the connection (if any)
            json(conn, %{
              success: true,
              printers: printers,
              source: "websocket_cache"
            })
          
          {:error, :not_found} ->
            # Client not connected via WebSocket
            json(conn, %{
              success: false,
              error: "Client not connected",
              message: "Desktop client must be online to fetch printers"
            })
        end
    end
  end
end
