defmodule GoprintRegistryWeb.DesktopSocket do
  use Phoenix.Socket

  channel "desktop:*", GoprintRegistryWeb.DesktopChannel
  alias GoprintRegistry.Clients

  defp ip_from_connect_info(connect_info, params) do
    with nil <- Map.get(params, "ip_address"),
         %{peer_data: %{address: addr}} <- connect_info do
      case addr do
        {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
        {a, b, c, d, e, f, g, h} ->
          Enum.map([a, b, c, d, e, f, g, h], &Integer.to_string(&1, 16))
          |> Enum.join(":")
        _ -> nil
      end
    else
      ip when is_binary(ip) -> ip
      _ ->
        # Try X-Forwarded-For if provided in headers connect_info
        case connect_info[:x_headers] do
          %{"x-forwarded-for" => ips} -> ips |> String.split(",") |> List.first() |> String.trim()
          _ -> nil
        end
    end
  end

  @impl true
  def connect(%{"ws_token" => token} = params, socket, connect_info) do
    require Logger
    Logger.info("DesktopSocket: Connection attempt with token")
    
    # Verify the WebSocket token from login
    case Phoenix.Token.verify(GoprintRegistryWeb.Endpoint, "ws_client", token, max_age: 600) do
      {:ok, claims} ->
        client_id = claims["client_id"] || claims[:client_id]
        Logger.info("DesktopSocket: Token verified", client_id: client_id)
        
        if is_nil(client_id) do
          Logger.error("DesktopSocket: No client_id in token claims")
          :error
        else
          # Update connection info if provided
          ip_address = ip_from_connect_info(connect_info || %{}, params)
          if ip_address, do: Clients.log_ip_address(client_id, ip_address)
          
          # Store client info in socket
          client = %{
            id: client_id, 
            connected_at: DateTime.utc_now(),
            authenticated_at: claims["authenticated_at"] || claims[:authenticated_at]
          }
          Logger.info("DesktopSocket: Connection accepted", client_id: client_id)
          {:ok, assign(socket, :client, client)}
        end
        
      {:error, :expired} ->
        Logger.error("DesktopSocket: Token expired")
        {:error, "Token expired. Please login again."}
        
      error ->
        Logger.error("DesktopSocket: Invalid token", error: inspect(error))
        {:error, "Invalid token"}
    end
  end

  def connect(params, _socket, _connect_info) do
    require Logger
    Logger.error("DesktopSocket: Connection attempt without ws_token", params: inspect(params))
    {:error, "Missing WebSocket token. Please login first."}
  end

  @impl true
  def id(socket), do: "desktop:#{socket.assigns.client.id}"
end
