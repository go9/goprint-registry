defmodule GoprintRegistry.ConnectionManager do
  @moduledoc """
  Manages WebSocket connections from desktop clients
  """
  use GenServer
  require Logger
  alias GoprintRegistry.Clients
  alias Phoenix.PubSub

  @table_name :desktop_connections
  @heartbeat_timeout 30_000  # 30 seconds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_desktop(client_id, pid) do
    GenServer.call(__MODULE__, {:register, client_id, pid})
  end

  def unregister_desktop(client_id) do
    GenServer.cast(__MODULE__, {:unregister, client_id})
  end

  def heartbeat(client_id) do
    GenServer.cast(__MODULE__, {:heartbeat, client_id})
  end

  def update_printers(client_id, printers) do
    GenServer.cast(__MODULE__, {:update_printers, client_id, printers})
  end

  def get_client(client_id) do
    case :ets.lookup(@table_name, client_id) do
      [{^client_id, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  def list_connected_clients do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {id, data} -> Map.put(data, :id, id) end)
  end

  def list_connections do
    :ets.tab2list(@table_name)
  end

  def send_print_job(client_id, job) do
    case get_client(client_id) do
      {:ok, %{pid: pid}} ->
        send(pid, {:print_job, job})
        :ok
      {:error, _} ->
        {:error, "Desktop client not connected"}
    end
  end

  def request_printers(client_id, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:request_printers, client_id, timeout}, timeout + 1000)
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule heartbeat check
    Process.send_after(self(), :check_heartbeats, @heartbeat_timeout)
    
    Logger.info("ConnectionManager started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, client_id, pid}, _from, state) do
    Logger.info("=== ConnectionManager registering client #{client_id} ===")
    data = %{
      pid: pid,
      connected_at: DateTime.utc_now(),
      last_heartbeat: System.system_time(:millisecond),
      printers: []
    }
    
    # Monitor the process
    Process.monitor(pid)
    
    :ets.insert(@table_name, {client_id, data})
    Logger.info("Client #{client_id} added to ETS table with pid #{inspect(pid)}")

    # Update persistent client state and notify associated users
    case Clients.connect_client(client_id, data.printers) do
      {:ok, client} ->
        Logger.info("Client #{client_id} status updated to connected in DB")
        broadcast_to_users(client_id, {:client_connected, client})
        Logger.info("Broadcasted connection to associated users")
      {:error, reason} ->
        Logger.error("Failed to update client #{client_id} connect status: #{inspect(reason)}")
        :ok
    end
    
    {:reply, :ok, Map.put(state, pid, client_id)}
  end

  @impl true
  def handle_call({:request_printers, client_id, timeout}, from, state) do
    case get_client(client_id) do
      {:ok, %{pid: pid}} ->
        # Generate a unique request ID
        request_id = :erlang.unique_integer([:positive, :monotonic])
        
        # Store the pending request
        new_state = Map.put(state, {:printer_request, request_id}, {from, :os.system_time(:millisecond)})
        
        # Send request to desktop client with request_id
        send(pid, {:request_printers, request_id})
        
        # Set a timeout to cleanup if no response
        Process.send_after(self(), {:printer_request_timeout, request_id}, timeout)
        
        {:noreply, new_state}
        
      {:error, _} ->
        {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_cast({:unregister, client_id}, state) do
    Logger.info("=== ConnectionManager unregistering client #{client_id} ===")
    :ets.delete(@table_name, client_id)
    Logger.info("Removed client #{client_id} from ETS table")

    # Persist disconnect and notify associated users
    case Clients.disconnect_client(client_id) do
      {:ok, _client} -> 
        Logger.info("Client #{client_id} status updated to disconnected in DB")
        broadcast_to_users(client_id, {:client_disconnected, client_id})
        Logger.info("Broadcasted disconnection to associated users")
      error -> 
        Logger.error("Failed to update client #{client_id} disconnect status: #{inspect(error)}")
        :ok
    end
    
    # Remove from state
    state = Enum.reduce(state, %{}, fn
      {_pid, cid}, acc when cid == client_id -> acc
      {pid, cid}, acc -> Map.put(acc, pid, cid)
    end)
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:heartbeat, client_id}, state) do
    case :ets.lookup(@table_name, client_id) do
      [{^client_id, data}] ->
        updated_data = Map.put(data, :last_heartbeat, System.system_time(:millisecond))
        :ets.insert(@table_name, {client_id, updated_data})
      [] ->
        :ok
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_printers, client_id, printers}, state) do
    case :ets.lookup(@table_name, client_id) do
      [{^client_id, data}] ->
        updated_data = Map.put(data, :printers, printers)
        :ets.insert(@table_name, {client_id, updated_data})
        Logger.info("Updated printer list for #{client_id}: #{length(printers)} printers")
        # Persist printer list
        _ = Clients.update_client_printers(client_id, printers)
        # Notify associated users
        broadcast_to_users(client_id, {:printers_updated, client_id, printers})
      [] ->
        :ok
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_heartbeats, state) do
    now = System.system_time(:millisecond)
    timeout = @heartbeat_timeout * 2  # Allow 2x heartbeat interval before disconnect
    
    expired = :ets.foldl(
      fn {client_id, data}, acc ->
        if now - data.last_heartbeat > timeout do
          [client_id | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    
    Enum.each(expired, fn client_id ->
      Logger.warning("Client #{client_id} timed out")
      :ets.delete(@table_name, client_id)
    end)
    
    # Schedule next check
    Process.send_after(self(), :check_heartbeats, @heartbeat_timeout)
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Process died, remove from registry
    case Map.get(state, pid) do
      nil -> 
        {:noreply, state}
      client_id ->
        :ets.delete(@table_name, client_id)
        Logger.info("Desktop client #{client_id} process terminated")
        # Persist disconnect and notify associated users
        case Clients.disconnect_client(client_id) do
          {:ok, _} -> broadcast_to_users(client_id, {:client_disconnected, client_id})
          _ -> :ok
        end
        {:noreply, Map.delete(state, pid)}
    end
  end

  defp broadcast_to_users(client_id, message) do
    for %{user: user} <- Clients.get_client_users(client_id) do
      PubSub.broadcast(GoprintRegistry.PubSub, "clients:#{user.id}", message)
    end
  end
end
