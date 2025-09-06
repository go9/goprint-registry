defmodule GoprintRegistry.Clients do
  @moduledoc """
  The Clients context.
  """

  import Ecto.Query, warn: false
  alias GoprintRegistry.Repo
  alias GoprintRegistry.Clients.Client

  @doc """
  Returns the list of clients for a user.
  """
  def list_clients(user_id) do
    Client
    |> where(user_id: ^user_id)
    |> order_by(desc: :last_connected_at)
    |> Repo.all()
  end

  @doc """
  Gets a single client.
  """
  def get_client!(id), do: Repo.get!(Client, id)

  def get_client(id), do: Repo.get(Client, id)

  def get_client_by(attrs), do: Repo.get_by(Client, attrs)

  @doc """
  Creates a client.
  """
  def create_client(attrs \\ %{}) do
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a client.
  """
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates client connection status.
  """
  def update_client_connection(%Client{} = client, attrs) do
    client
    |> Client.connection_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a client.
  """
  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client changes.
  """
  def change_client(%Client{} = client, attrs \\ %{}) do
    Client.changeset(client, attrs)
  end

  @doc """
  Connect a client (update status and timestamp).
  """
  def connect_client(client_id, api_key, user_id) do
    case get_client_by(client_id: client_id, user_id: user_id) do
      nil ->
        create_client(%{
          client_id: client_id,
          api_key: api_key,
          user_id: user_id,
          status: "connected",
          last_connected_at: DateTime.utc_now()
        })
      
      client ->
        update_client_connection(client, %{
          status: "connected",
          last_connected_at: DateTime.utc_now()
        })
    end
  end

  @doc """
  Disconnect a client.
  """
  def disconnect_client(client_id, user_id) do
    case get_client_by(client_id: client_id, user_id: user_id) do
      nil -> {:error, :not_found}
      client ->
        update_client_connection(client, %{status: "disconnected"})
    end
  end

  @doc """
  Update client printers.
  """
  def update_client_printers(client_id, user_id, printers) do
    case get_client_by(client_id: client_id, user_id: user_id) do
      nil -> {:error, :not_found}
      client ->
        update_client_connection(client, %{printers: printers})
    end
  end
end