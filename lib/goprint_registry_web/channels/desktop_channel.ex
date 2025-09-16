defmodule GoprintRegistryWeb.DesktopChannel do
  use Phoenix.Channel
  require Logger

  alias GoprintRegistry.{ConnectionManager, JobQueue, Clients}

  @impl true
  def join("desktop:lobby", _params, socket) do
    client = socket.assigns.client
    # Defensive: refuse join if the client record does not exist.
    # Cloud should either have auto-provisioned it in socket connect
    # or it must have been registered previously via HTTP.
    case Clients.get_client(client.id) do
      nil ->
        {:error, %{reason: "unknown_client"}}
      _ ->

        # Register this desktop client
        require Logger
        Logger.info("DesktopChannel: Registering client", client_id: client.id)
        ConnectionManager.register_desktop(client.id, self())
        
        # Subscribe to PubSub topic for this client to receive print jobs
        Phoenix.PubSub.subscribe(GoprintRegistry.PubSub, "desktop:#{client.id}")
    
        # No longer request printer list on join - it's now on-demand
    
        {:ok, %{status: "connected", client_id: client.id}, socket}
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
    # Update job status
    details = Map.get(payload, "details")
    JobQueue.update_job_status(job_id, status, details)
    
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
    ConnectionManager.unregister_desktop(client_id)
    :ok
  end
end
