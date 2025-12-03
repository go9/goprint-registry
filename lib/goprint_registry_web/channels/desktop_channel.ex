defmodule GoprintRegistryWeb.DesktopChannel do
  use Phoenix.Channel
  require Logger

  alias GoprintRegistry.{ConnectionManager, JobQueue, Clients}

  @impl true
  def join("desktop:lobby", _params, socket) do
    require Logger
    Logger.info("DesktopChannel: Join attempt for desktop:lobby")
    
    client = socket.assigns[:client]
    
    if is_nil(client) do
      Logger.error("DesktopChannel: No client in socket assigns")
      {:error, %{reason: "no_client_in_socket"}}
    else
      Logger.info("DesktopChannel: Client found in socket", client_id: client.id)
      
      # Defensive: refuse join if the client record does not exist.
      # Cloud should either have auto-provisioned it in socket connect
      # or it must have been registered previously via HTTP.
      case Clients.get_client(client.id) do
        nil ->
          Logger.error("DesktopChannel: Client not found in database", client_id: client.id)
          {:error, %{reason: "unknown_client"}}
        _db_client ->
          Logger.info("DesktopChannel: Client found in database", client_id: client.id)
          
          # Register this desktop client
          Logger.info("DesktopChannel: Registering client with ConnectionManager", client_id: client.id)
          case ConnectionManager.register_desktop(client.id, self()) do
            :ok ->
              Logger.info("DesktopChannel: Successfully registered with ConnectionManager", client_id: client.id)
            error ->
              Logger.error("DesktopChannel: Failed to register with ConnectionManager", client_id: client.id, error: inspect(error))
          end
          
          # Subscribe to PubSub topic for this client to receive print jobs
          Phoenix.PubSub.subscribe(GoprintRegistry.PubSub, "desktop:#{client.id}")
      
          # No longer request printer list on join - it's now on-demand
      
          {:ok, %{status: "connected", client_id: client.id}, socket}
      end
    end
  end

  @impl true
  def handle_in("auth", %{"client_id" => _client_id, "client_secret" => _client_secret}, socket) do
    # Already authenticated in socket connect
    {:reply, {:ok, %{type: "auth_success", message: "Authenticated"}}, socket}
  end

  @impl true
  def handle_in("heartbeat", _payload, socket) do
    # Cheap: only update in-memory heartbeat; DB was updated on connect
    ConnectionManager.heartbeat(socket.assigns.client.id)
    {:reply, {:ok, %{type: "pong"}}, socket}
  end

  @impl true
  def handle_in("printer_list", params, socket) do
    printers = Map.get(params, "printers", [])
    request_id = Map.get(params, "request_id")
    
    if request_id do
      # This is a response to a specific request
      send(ConnectionManager, {:printer_response, request_id, printers})
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_in("printer_response", params, socket) do
    printers = Map.get(params, "printers", [])
    request_id = Map.get(params, "request_id")
    
    if request_id do
      # This is a response to a specific request
      send(ConnectionManager, {:printer_response, request_id, printers})
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_in("job_status", %{"job_id" => job_id, "status" => status} = payload, socket) do
    # Update in-memory queue status
    details = Map.get(payload, "details")
    JobQueue.update_job_status(job_id, status, details)

    # Also update persistent DB status when possible
    try do
      case GoprintRegistry.PrintJobs.get_print_job_by_job_id(job_id) do
        nil -> :ok
        job ->
          db_status = case status do
            "received" -> "acknowledged"
            "completed" -> "completed"
            "error" -> "failed"
            other -> other
          end
          # Only update if mapped status is valid string
          if is_binary(db_status) do
            _ = GoprintRegistry.PrintJobs.update_job_status(job, db_status, details)
          end
      end
    rescue e ->
      Logger.error("Failed to persist job status update", error: inspect(e), job_id: job_id, status: status)
    end
    
    # Notify developer who submitted the job
    JobQueue.notify_job_status(job_id, status, details)
    
    {:noreply, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:request_printers, request_id}, socket) do
    # Request fresh printer list from desktop client
    push(socket, "request_printers", %{request_id: request_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:print_job, job}, socket) do
    # Forward print job to desktop client
    require Logger
    Logger.info("DesktopChannel: Forwarding print job to desktop client", 
      job_id: job[:job_id], 
      client_id: socket.assigns[:client_id] || socket.assigns[:client][:id],
      printer_id: job[:printer_id],
      socket_pid: inspect(self())
    )
    
    result = push(socket, "print_job", job)
    
    Logger.info("DesktopChannel: Push result", 
      result: inspect(result),
      job_id: job[:job_id]
    )
    
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    client_id = socket.assigns.client.id
    ConnectionManager.unregister_desktop(client_id, self())
    :ok
  end
end
