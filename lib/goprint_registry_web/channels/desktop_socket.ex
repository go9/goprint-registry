defmodule GoprintRegistryWeb.DesktopSocket do
  use Phoenix.Socket

  channel "desktop:*", GoprintRegistryWeb.DesktopChannel

  @impl true
  def connect(%{"client_id" => client_id, "client_secret" => client_secret}, socket, _connect_info) do
    # Authenticate the desktop client
    case authenticate_client(client_id, client_secret) do
      {:ok, client} ->
        {:ok, assign(socket, :client, client)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def connect(_params, _socket, _connect_info) do
    {:error, "Missing authentication credentials"}
  end

  @impl true
  def id(socket), do: "desktop:#{socket.assigns.client.id}"

  defp authenticate_client(client_id, client_secret) do
    # For now, generate a client record
    # In production, validate against stored credentials
    {:ok, %{
      id: client_id,
      secret: client_secret,
      connected_at: DateTime.utc_now()
    }}
  end
end