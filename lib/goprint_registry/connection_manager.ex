defmodule GoprintRegistry.ConnectionManager do
  @moduledoc """
  Manages WebSocket connections from desktop clients
  """
  use GenServer
  require Logger

  @table_name :desktop_connections
  @heartbeat_timeout 60_000  # 60 seconds

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

  def get_desktop_client(client_id) do
    case :ets.lookup(@table_name, client_id) do
      [{^client_id, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  def list_connected_clients do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {id, data} -> Map.put(data, :id, id) end)
  end

  def send_print_job(client_id, job) do
    case get_desktop_client(client_id) do
      {:ok, %{pid: pid}} ->
        send(pid, {:print_job, job})
        :ok
      {:error, _} ->
        {:error, "Desktop client not connected"}
    end
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
    data = %{
      pid: pid,
      connected_at: DateTime.utc_now(),
      last_heartbeat: System.system_time(:millisecond),
      printers: []
    }
    
    # Monitor the process
    Process.monitor(pid)
    
    :ets.insert(@table_name, {client_id, data})
    Logger.info("Desktop client registered: #{client_id}")
    
    {:reply, :ok, Map.put(state, pid, client_id)}
  end

  @impl true
  def handle_cast({:unregister, client_id}, state) do
    :ets.delete(@table_name, client_id)
    Logger.info("Desktop client unregistered: #{client_id}")
    
    # Remove from state
    state = Enum.reduce(state, %{}, fn
      {pid, cid}, acc when cid == client_id -> acc
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
      Logger.warn("Desktop client #{client_id} timed out")
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
        {:noreply, Map.delete(state, pid)}
    end
  end
end