defmodule GoprintRegistry.Clients do
  @moduledoc """
  The Clients context.
  """

  import Ecto.Query, warn: false
  alias GoprintRegistry.Repo
  alias GoprintRegistry.Clients.{Client, ClientUser, ClientIpAddress}
  alias GoprintRegistry.Accounts.User
  alias Flop

  @doc """
  Counts the total number of clients.
  """
  def count_clients do
    Repo.aggregate(Client, :count, :id)
  end

  @doc """
  Counts the number of active clients (connected in last 5 minutes).
  """
  def count_active_clients do
    five_minutes_ago = DateTime.add(DateTime.utc_now(), -300, :second)
    
    from(c in Client,
      where: c.last_connected_at > ^five_minutes_ago
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists all clients.
  """
  def list_clients do
    Repo.all(Client)
  end

  @doc """
  Lists clients with Flop pagination and filtering.
  """
  def list_clients_with_flop(flop \\ %Flop{}) do
    query = from(c in Client, order_by: [desc: c.last_connected_at])
    Flop.run(query, flop, for: Client)
  end

  @doc """
  Returns the list of clients for a user through the join table.
  """
  def list_clients_for_user(user_id) do
    from(c in Client,
      join: cu in ClientUser, on: cu.client_id == c.id,
      where: cu.user_id == ^user_id and cu.is_active == true,
      order_by: [desc: c.last_connected_at],
      preload: [:client_users, :ip_addresses]
    )
    |> Repo.all()
  end

  @doc """
  Lists clients for a user with Flop pagination and filtering.
  """
  def list_clients_for_user_with_flop(user_id, flop \\ %Flop{}) do
    query = from(c in Client,
      join: cu in ClientUser, on: cu.client_id == c.id,
      where: cu.user_id == ^user_id and cu.is_active == true,
      order_by: [desc: c.last_connected_at],
      preload: [:client_users, :ip_addresses]
    )
    Flop.run(query, flop, for: Client)
  end

  @doc """
  Gets a single client.
  """
  def get_client!(id), do: Repo.get!(Client, id)

  def get_client(id), do: Repo.get(Client, id)

  def get_client_by(attrs), do: Repo.get_by(Client, attrs)


  def get_client_by_mac_address(mac_address) do
    Repo.get_by(Client, mac_address: mac_address)
  end

  @doc """
  Ensures a client with the given id exists. If missing, provisions a new
  client record with minimal information. Intended for WS auto-activation
  when the agent has a UUID but hasn't registered via HTTP yet.
  """
  def ensure_client_exists(client_id, attrs \\ %{}) do
    case get_client(client_id) do
      nil ->
        # Use a unique placeholder MAC to satisfy validation
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        base_attrs = %{
          api_name: Map.get(attrs, :api_name, "Desktop Client"),
          mac_address: "unknown:" <> client_id,
          operating_system: Map.get(attrs, :operating_system, nil),
          app_version: Map.get(attrs, :app_version, nil),
          registered_at: now
        }

        %Client{id: client_id}
        |> Client.registration_changeset(base_attrs)
        |> Repo.insert()

      client ->
        {:ok, client}
    end
  end

  @doc """
  Ensures a client exists and persists identifying metadata provided by the agent
  on WebSocket connect. Does not mark the client connected; ConnectionManager
  updates connection state on channel join.
  """
  def register_or_update_on_connect(client_id, attrs, ip_address \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Map.merge(%{api_name: "Desktop Client"}, attrs)

    case get_client(client_id) do
      nil ->
        reg_attrs =
          attrs
          |> Map.take([:api_name, :mac_address, :operating_system, :app_version])
          |> Map.put(:registered_at, now)

        with {:ok, client} <- %Client{id: client_id} |> Client.registration_changeset(reg_attrs) |> Repo.insert() do
          if ip_address, do: log_ip_address(client.id, ip_address)
          {:ok, client}
        end

      %Client{} = client ->
        # Update metadata if provided; ignore connection fields here
        update_attrs = Map.take(attrs, [:api_name, :mac_address, :operating_system, :app_version])
        client =
          case update_attrs do
            m when map_size(m) == 0 -> client
            _ ->
              case client |> Client.changeset(update_attrs) |> Repo.update() do
                {:ok, c} -> c
                _ -> client
              end
          end

        if ip_address, do: log_ip_address(client.id, ip_address)
        {:ok, client}
    end
  end

  @doc """
  Creates a client (desktop self-registration).
  Also logs the IP address if provided.
  """
  def create_client(attrs \\ %{}, ip_address \\ nil) do
    result = %Client{}
    |> Client.registration_changeset(attrs)
    |> Repo.insert()
    
    case result do
      {:ok, client} ->
        if ip_address do
          log_ip_address(client.id, ip_address)
        end
        {:ok, client}
      error -> error
    end
  end

  @doc """
  Associates a user with a client by client ID.
  Returns {:ok, client_user} or {:error, reason}
  """
  def associate_user_with_client(user_id, client_id) do
    case get_client(client_id) do
      nil -> 
        {:error, :invalid_client_id}
      client ->
        create_or_activate_client_user(client.id, user_id)
    end
  end

  defp create_or_activate_client_user(client_id, user_id) do
    # Check if association already exists
    existing = Repo.get_by(ClientUser, client_id: client_id, user_id: user_id)
    
    case existing do
      nil ->
        # Create new association
        %ClientUser{}
        |> ClientUser.changeset(%{
          client_id: client_id,
          user_id: user_id,
          added_at: DateTime.utc_now() |> DateTime.truncate(:second),
          is_active: true
        })
        |> Repo.insert()
      
      client_user ->
        # Reactivate if it was deactivated
        if not client_user.is_active do
          client_user
          |> Ecto.Changeset.change(%{is_active: true})
          |> Repo.update()
        else
          {:error, :already_associated}
        end
    end
  end

  @doc """
  Removes association between user and client (soft delete).
  """
  def disassociate_user_from_client(user_id, client_id) do
    case Repo.get_by(ClientUser, client_id: client_id, user_id: user_id) do
      nil -> {:error, :not_found}
      client_user ->
        client_user
        |> Ecto.Changeset.change(%{is_active: false})
        |> Repo.update()
    end
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
  Deletes a client entirely (hard delete).
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
  Update heartbeat timestamp without changing connection status.
  Used for HTTP heartbeats which don't indicate a WebSocket connection.
  """
  def update_heartbeat(client_id) do
    case get_client(client_id) do
      nil ->
        {:error, :not_found}
      
      client ->
        client
        |> Client.changeset(%{
          last_connected_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  @doc """
  Mark stale clients as disconnected.
  Clients are considered stale if no heartbeat for 90 seconds.
  """
  def disconnect_stale_clients() do
    threshold = DateTime.utc_now() |> DateTime.add(-90, :second)
    
    from(c in Client,
      where: c.status == "connected" and c.last_connected_at < ^threshold
    )
    |> Repo.update_all(set: [status: "disconnected", updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end

  @doc """
  Desktop client connects (update status and timestamp).
  Used when WebSocket connection is established.
  """
  def connect_client(client_id) do
    case get_client(client_id) do
      nil ->
        {:error, :not_found}
      
      client ->
        update_client_connection(client, %{
          status: "connected",
          last_connected_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end
  end

  @doc """
  Desktop client disconnects.
  """
  def disconnect_client(client_id) do
    case get_client(client_id) do
      nil -> {:error, :not_found}
      client ->
        update_client_connection(client, %{status: "disconnected"})
    end
  end

  @doc """
  Get all users associated with a client.
  """
  def get_client_users(client_id) do
    from(u in User,
      join: cu in ClientUser, on: cu.user_id == u.id,
      where: cu.client_id == ^client_id and cu.is_active == true,
      select: %{user: u, added_at: cu.added_at, permissions: cu.permissions}
    )
    |> Repo.all()
  end

  @doc """
  List all clients associated with a user.
  """
  def list_user_clients(user_id) do
    from(c in Client,
      join: cu in ClientUser, on: cu.client_id == c.id,
      where: cu.user_id == ^user_id and cu.is_active == true,
      select: c
    )
    |> Repo.all()
  end

  @doc """
  Check if a user has access to a client.
  """
  def user_has_access?(user_id, client_id) do
    Repo.exists?(
      from cu in ClientUser,
        where: cu.user_id == ^user_id and 
               cu.client_id == ^client_id and 
               cu.is_active == true
    )
  end
  
  @doc """
  Remove association between user and client.
  """
  def unassociate_user_from_client(user_id, client_id) do
    case Repo.get_by(ClientUser, user_id: user_id, client_id: client_id, is_active: true) do
      nil ->
        {:error, :not_found}
      
      client_user ->
        client_user
        |> Ecto.Changeset.change(%{is_active: false})
        |> Repo.update()
    end
  end
  
  @doc """
  Log or update an IP address for a client.
  """
  def log_ip_address(client_id, ip_address) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    case Repo.get_by(ClientIpAddress, client_id: client_id, ip_address: ip_address) do
      nil ->
        # New IP address for this client
        %ClientIpAddress{}
        |> ClientIpAddress.changeset(%{
          client_id: client_id,
          ip_address: ip_address,
          first_seen: now,
          last_seen: now,
          connection_count: 1
        })
        |> Repo.insert()
      
      existing ->
        # Update existing IP record
        existing
        |> Ecto.Changeset.change(%{
          last_seen: now,
          connection_count: existing.connection_count + 1
        })
        |> Repo.update()
    end
  end
  
  def get_client_ip_addresses(client_id) do
    from(ip in ClientIpAddress,
      where: ip.client_id == ^client_id,
      order_by: [desc: ip.last_seen]
    )
    |> Repo.all()
  end
end
