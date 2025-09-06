defmodule GoprintRegistryWeb.DesktopChannel do
  use Phoenix.Channel
  require Logger

  alias GoprintRegistry.{ConnectionManager, JobQueue}

  @impl true
  def join("desktop:lobby", _params, socket) do
    client = socket.assigns.client
    
    # Register this desktop client
    ConnectionManager.register_desktop(client.id, self())
    
    # Send initial printer list request
    send(self(), :request_printer_list)
    
    {:ok, %{status: "connected", client_id: client.id}, socket}
  end

  @impl true
  def handle_in("auth", %{"client_id" => client_id, "client_secret" => client_secret}, socket) do
    # Already authenticated in socket connect
    {:reply, {:ok, %{type: "auth_success", message: "Authenticated"}}, socket}
  end

  @impl true
  def handle_in("heartbeat", payload, socket) do
    # Update last seen timestamp
    ConnectionManager.heartbeat(socket.assigns.client.id)
    {:reply, {:ok, %{type: "pong"}}, socket}
  end

  @impl true
  def handle_in("printer_list", %{"printers" => printers}, socket) do
    # Store the printer list for this client
    ConnectionManager.update_printers(socket.assigns.client.id, printers)
    
    Logger.info("Received printer list from #{socket.assigns.client.id}: #{length(printers)} printers")
    
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
  def handle_info(:request_printer_list, socket) do
    push(socket, "get_printers", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:print_job, job}, socket) do
    # Forward print job to desktop client
    push(socket, "print_job", job)
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    client_id = socket.assigns.client.id
    ConnectionManager.unregister_desktop(client_id)
    Logger.info("Desktop client #{client_id} disconnected: #{inspect(reason)}")
    :ok
  end
end