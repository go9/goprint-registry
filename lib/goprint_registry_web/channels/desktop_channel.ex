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
        Logger.warning("Rejecting join for unknown client #{client.id}")
        {:error, %{reason: "unknown_client"}}
      _ ->

        # Register this desktop client
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
    client_id = socket.assigns.client.id
    
    if request_id do
      # This is a response to a specific request
      send(ConnectionManager, {:printer_response, request_id, printers})
      Logger.info("Received printer list response from #{client_id} for request #{request_id}: #{length(printers)} printers")
    else
      # Legacy response without request_id - ignore
      Logger.warn("Received printer list without request_id from #{client_id} - ignoring")
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
    
    Logger.info("Job #{job_id} status: #{status}")
    
    {:noreply, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    Logger.debug("Received unknown event #{event}: #{inspect(payload)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:request_printers, request_id}, socket) do
    Logger.info("Desktop channel requesting printers with request_id #{request_id}")
    # Request fresh printer list from desktop client
    push(socket, "get_printers", %{request_id: request_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:print_job, job}, socket) do
    Logger.info("Desktop channel forwarding print job #{inspect(job[:job_id])} to client #{socket.assigns.client.id}")
    
    # Forward print job to desktop client
    push(socket, "print_job", job)
    
    Logger.info("Print job #{inspect(job[:job_id])} pushed to desktop client via WebSocket")
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    client_id = socket.assigns.client.id
    Logger.info("=== Desktop channel terminate called ===")
    Logger.info("Client #{client_id} disconnecting, reason: #{inspect(reason)}")
    ConnectionManager.unregister_desktop(client_id)
    Logger.info("Desktop client #{client_id} unregistered from ConnectionManager")
    :ok
  end
end
