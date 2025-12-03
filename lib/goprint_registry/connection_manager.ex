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

  def unregister_desktop(client_id, pid \\ nil) do
    GenServer.cast(__MODULE__, {:unregister, client_id, pid})
  end

  def heartbeat(client_id) do
    GenServer.cast(__MODULE__, {:heartbeat, client_id})
  end


  def get_client(client_id) do
    require Logger
    
    # Log all connected clients for debugging
    all_clients = :ets.tab2list(@table_name)
    Logger.info("ConnectionManager: Looking for client", 
      looking_for: client_id, 
      connected_clients: Enum.map(all_clients, fn {id, _} -> id end)
    )
    
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

  @job_delivery_timeout 5_000  # 5 seconds to acknowledge job receipt

  def send_print_job(client_id, job) do
    GenServer.call(__MODULE__, {:send_print_job, client_id, job}, @job_delivery_timeout + 1_000)
  end

  def request_printers(client_id, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:request_printers, client_id, timeout}, timeout + 1000)
  end

  def request_printer_capabilities(client_id, printer_id, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:request_printer_capabilities, client_id, printer_id, timeout}, timeout + 1000)
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule heartbeat check
    Process.send_after(self(), :check_heartbeats, @heartbeat_timeout)
    
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, client_id, pid}, _from, state) do
    require Logger
    Logger.info("ConnectionManager: Registering client", 
      client_id: client_id,
      pid: inspect(pid)
    )
    
    data = %{
      pid: pid,
      connected_at: DateTime.utc_now(),
      last_heartbeat: System.system_time(:millisecond)
    }
    
    # Monitor the process
    Process.monitor(pid)
    
    :ets.insert(@table_name, {client_id, data})
    
    Logger.info("ConnectionManager: Client registered successfully", 
      client_id: client_id
    )

    # Update persistent client state and notify associated users
    case Clients.connect_client(client_id) do
      {:ok, client} ->
        broadcast_to_users(client_id, {:client_connected, client})
      {:error, reason} ->
        Logger.error("Failed to update client #{client_id} connect status: #{inspect(reason)}")
        :ok
    end
    
    {:reply, :ok, Map.put(state, pid, client_id)}
  end

  @impl true
  def handle_call({:send_print_job, client_id, job}, from, state) do
    require Logger
    Logger.info("ConnectionManager: Attempting to send print job", client_id: client_id, job_id: job[:job_id])

    case get_client(client_id) do
      {:ok, %{pid: pid}} ->
        # Generate a unique delivery ID for acknowledgment
        delivery_id = :erlang.unique_integer([:positive, :monotonic])

        Logger.info("ConnectionManager: Client found, sending job with delivery confirmation",
          pid: inspect(pid),
          delivery_id: delivery_id
        )

        # Store the pending delivery
        new_state = Map.put(state, {:job_delivery, delivery_id}, {from, job[:job_id], :os.system_time(:millisecond)})

        # Send job to channel process with delivery_id for acknowledgment
        send(pid, {:print_job, job, delivery_id})

        # Set a timeout for acknowledgment
        Process.send_after(self(), {:job_delivery_timeout, delivery_id}, @job_delivery_timeout)

        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning("ConnectionManager: Client not found", client_id: client_id, reason: reason)
        {:reply, {:error, "Desktop client not connected"}, state}
    end
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
  def handle_cast({:unregister, client_id, requesting_pid}, state) do
    require Logger

    # Only unregister if the requesting PID matches the current connection,
    # or if no PID was provided (for backwards compatibility)
    should_unregister = case :ets.lookup(@table_name, client_id) do
      [] ->
        # No entry found, nothing to do
        false
      [{^client_id, %{pid: current_pid}}] ->
        cond do
          requesting_pid == nil ->
            # No PID provided, proceed (legacy behavior)
            true
          requesting_pid == current_pid ->
            # PID matches, safe to unregister
            true
          true ->
            # PID doesn't match - a newer connection exists
            Logger.info("ConnectionManager: Ignoring stale unregister (already reconnected)",
              client_id: client_id,
              requesting_pid: inspect(requesting_pid),
              current_pid: inspect(current_pid)
            )
            false
        end
    end

    if should_unregister do
      :ets.delete(@table_name, client_id)

      # Persist disconnect and notify associated users
      case Clients.disconnect_client(client_id) do
        {:ok, _client} ->
          broadcast_to_users(client_id, {:client_disconnected, client_id})
        error ->
          Logger.error("Failed to update client #{client_id} disconnect status: #{inspect(error)}")
          :ok
      end
    end

    # Remove the requesting PID from state (if it's there)
    new_state = if requesting_pid do
      Map.delete(state, requesting_pid)
    else
      # Legacy: remove all entries for this client_id
      Enum.reduce(state, %{}, fn
        {_pid, cid}, acc when cid == client_id -> acc
        {pid, cid}, acc -> Map.put(acc, pid, cid)
      end)
    end

    {:noreply, new_state}
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
      # Remove from in-memory table
      :ets.delete(@table_name, client_id)

      # Persist disconnect and notify associated users to avoid stale "connected" state
      case Clients.disconnect_client(client_id) do
        {:ok, _client} -> broadcast_to_users(client_id, {:client_disconnected, client_id})
        error -> Logger.error("Failed to update client disconnect on heartbeat timeout", client_id: client_id, error: inspect(error))
      end
    end)
    
    # Schedule next check
    Process.send_after(self(), :check_heartbeats, @heartbeat_timeout)
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:printer_response, request_id, printers}, state) do
    case Map.get(state, {:printer_request, request_id}) do
      {from, _timestamp} ->
        # Reply to the waiting caller
        GenServer.reply(from, {:ok, printers})
        # Clean up the request
        {:noreply, Map.delete(state, {:printer_request, request_id})}
      nil ->
        # Request already timed out or doesn't exist
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:printer_request_timeout, request_id}, state) do
    case Map.get(state, {:printer_request, request_id}) do
      {from, _timestamp} ->
        # Reply with timeout error
        GenServer.reply(from, {:error, :timeout})
        # Clean up the request
        {:noreply, Map.delete(state, {:printer_request, request_id})}
      nil ->
        # Already handled
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:job_delivered, delivery_id}, state) do
    require Logger
    case Map.get(state, {:job_delivery, delivery_id}) do
      {from, job_id, _timestamp} ->
        Logger.info("ConnectionManager: Job delivery confirmed", delivery_id: delivery_id, job_id: job_id)
        # Reply success to the waiting caller
        GenServer.reply(from, :ok)
        # Clean up the pending delivery
        {:noreply, Map.delete(state, {:job_delivery, delivery_id})}
      nil ->
        # Already timed out or doesn't exist
        Logger.warning("ConnectionManager: Received ack for unknown delivery", delivery_id: delivery_id)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:job_delivery_timeout, delivery_id}, state) do
    require Logger
    case Map.get(state, {:job_delivery, delivery_id}) do
      {from, job_id, _timestamp} ->
        Logger.error("ConnectionManager: Job delivery timed out", delivery_id: delivery_id, job_id: job_id)
        # Reply with timeout error
        GenServer.reply(from, {:error, "Job delivery timed out - desktop may be unresponsive"})
        # Clean up the pending delivery
        {:noreply, Map.delete(state, {:job_delivery, delivery_id})}
      nil ->
        # Already acknowledged
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    require Logger
    # Process died, remove from registry
    case Map.get(state, pid) do
      nil ->
        {:noreply, state}
      client_id ->
        # IMPORTANT: Only delete from ETS if the current entry still points to this PID.
        # This prevents a race condition where a new connection overwrites the old one
        # in ETS, but the old connection's :DOWN message arrives later and incorrectly
        # deletes the new connection's entry.
        case :ets.lookup(@table_name, client_id) do
          [{^client_id, %{pid: ^pid}}] ->
            # The ETS entry still points to this dying PID, safe to delete
            Logger.warning("ConnectionManager: Client disconnected",
              client_id: client_id,
              pid: inspect(pid),
              reason: inspect(reason)
            )
            :ets.delete(@table_name, client_id)
            # Persist disconnect and notify associated users
            case Clients.disconnect_client(client_id) do
              {:ok, _} -> broadcast_to_users(client_id, {:client_disconnected, client_id})
              _ -> :ok
            end
          _ ->
            # ETS entry was already overwritten by a newer connection, don't delete it
            Logger.info("ConnectionManager: Ignoring stale :DOWN for client (already reconnected)",
              client_id: client_id,
              old_pid: inspect(pid)
            )
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
