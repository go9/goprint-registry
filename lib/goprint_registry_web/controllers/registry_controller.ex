defmodule GoprintRegistryWeb.RegistryController do
  use GoprintRegistryWeb, :controller
  require Logger

  @ttl 300 # 5 minutes

  def register(conn, %{"api_key" => api_key, "ip" => ip, "port" => port} = params) do
    # Store in ETS for now (will add Redis later)
    data = %{
      ip: ip,
      port: port,
      name: params["name"] || "Unknown",
      version: params["version"] || "1.0.0",
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    :ets.insert(:goprint_registry, {api_key, data, System.system_time(:second)})
    
    Logger.info("GoPrint registered: #{api_key} at #{ip}:#{port}")
    
    json(conn, %{
      success: true,
      message: "Registered successfully",
      ttl: @ttl
    })
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: api_key, ip, port"})
  end

  def lookup(conn, %{"api_key" => api_key}) do
    case :ets.lookup(:goprint_registry, api_key) do
      [{^api_key, data, timestamp}] ->
        # Check if entry is still valid (not older than TTL)
        now = System.system_time(:second)
        if now - timestamp < @ttl do
          json(conn, %{
            success: true,
            service: data
          })
        else
          # Entry expired
          :ets.delete(:goprint_registry, api_key)
          conn
          |> put_status(:not_found)
          |> json(%{error: "Service not found or expired"})
        end
      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Service not found"})
    end
  end

  def status(conn, _params) do
    # Count active services
    now = System.system_time(:second)
    active_count = :ets.foldl(
      fn {_key, _data, timestamp}, acc ->
        if now - timestamp < @ttl, do: acc + 1, else: acc
      end,
      0,
      :goprint_registry
    )
    
    json(conn, %{
      active_services: active_count,
      ttl: @ttl,
      server_time: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end