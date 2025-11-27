defmodule GoprintRegistryWeb.ClientsLive.Index do
  use GoprintRegistryWeb, :live_view
  
  alias GoprintRegistry.{Clients, PrintJobs, ConnectionManager}
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GoprintRegistry.PubSub, "clients:#{socket.assigns.current_scope.user.id}")
      # Refresh connection status every 2 seconds
      :timer.send_interval(2000, self(), :refresh_connections)
    end
    
    clients = load_clients_with_connection_status(socket.assigns.current_scope.user.id)
    
    {:ok,
     socket
     |> assign(:clients, clients)
     |> assign(:page_title, "Clients")
     |> assign(:show_test_print_modal, false)
     |> assign(:selected_client, nil)
     |> assign(:test_print_form, to_form(%{
       "printer_id" => "",
       "paper_size" => "A4",
       "content" => "Test Print from GoPrint\n\nPrinter: [PRINTER_NAME]\nDate: #{DateTime.utc_now() |> DateTime.to_string()}\n\n✓ Connection successful\n✓ Print test successful"
     }))
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:add_client_form, to_form(%{"client_id" => ""}))
     |> assign(:show_ip_modal, false)
     |> assign(:show_client_modal, false)
     |> assign(:client_details, nil)
     |> assign(:print_job_status, nil)
     |> assign(:fetching_printers, false), 
     layout: {GoprintRegistryWeb.Layouts, :app}}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_filters(socket, params)}
  end
  
  defp apply_filters(socket, params) do
    status = params["status"] || "all"
    query = params["q"] || ""
    
    clients = load_clients_with_connection_status(socket.assigns.current_scope.user.id)
    
    filtered_clients = clients
    |> filter_by_status(status)
    |> filter_by_search(query)
    
    socket
    |> assign(:clients, filtered_clients)
    |> assign(:filter_status, status)
    |> assign(:search_query, query)
  end
  
  defp filter_by_status(clients, "all"), do: clients
  defp filter_by_status(clients, status) do
    Enum.filter(clients, &(&1.status == status))
  end
  
  defp filter_by_search(clients, ""), do: clients
  defp filter_by_search(clients, query) do
    query = String.downcase(query)
    Enum.filter(clients, fn client ->
      String.contains?(String.downcase(client.id || ""), query) ||
      String.contains?(String.downcase(client.api_name || ""), query) ||
      String.contains?(String.downcase(client.mac_address || ""), query)
    end)
  end
  
  @impl true
  def handle_event("add_client", %{"add_client" => %{"client_id" => client_id}}, socket) do
    client_id = String.trim(client_id)
    
    if client_id == "" do
      {:noreply, put_flash(socket, :error, "Client ID cannot be empty")}
    else
      case Clients.associate_user_with_client(socket.assigns.current_scope.user.id, client_id) do
        {:ok, _client_user} ->
          clients = load_clients_with_connection_status(socket.assigns.current_scope.user.id)
          {:noreply,
           socket
           |> put_flash(:info, "Client added successfully!")
           |> assign(:clients, clients)
           |> assign(:add_client_form, to_form(%{"client_id" => ""}))}
        
        {:error, :invalid_client_id} ->
          {:noreply, put_flash(socket, :error, "Invalid Client ID. Please check the ID from your desktop client and try again.")}
        
        {:error, :already_associated} ->
          {:noreply, put_flash(socket, :error, "This client is already associated with your account.")}
        
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add client")}
      end
    end
  end
  
  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    params = %{"q" => query, "status" => socket.assigns.filter_status}
    {:noreply, push_patch(socket, to: ~p"/clients?#{params}")}
  end
  
  @impl true
  def handle_event("delete_client", %{"id" => client_id}, socket) do
    # Disassociate user from client (soft delete)
    case Clients.disassociate_user_from_client(socket.assigns.current_scope.user.id, client_id) do
        {:ok, _} ->
          clients = load_clients_with_connection_status(socket.assigns.current_scope.user.id)
          {:noreply,
           socket
           |> put_flash(:info, "Client removed successfully")
           |> assign(:clients, clients)}
        
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove client")}
    end
  end
  
  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    params = %{"status" => status, "q" => socket.assigns.search_query}
    {:noreply, push_patch(socket, to: ~p"/clients?#{params}")}
  end
  
  @impl true
  def handle_event("show_client", %{"id" => client_id}, socket) do
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))
    
    if client do
      # Load additional client details
      client_with_details = %{
        client | 
        ip_addresses: Clients.get_client_ip_addresses(client_id),
        users: Clients.get_client_users(client_id)
      }
      
      # Don't auto-fetch, just show existing printers
      {:noreply,
       socket
       |> assign(:show_client_modal, true)
       |> assign(:client_details, client_with_details)
       |> assign(:fetching_printers, false)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("close_client_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_client_modal, false)
     |> assign(:client_details, nil)
     |> assign(:fetching_printers, false)}
  end
  
  @impl true
  def handle_event("refresh_printers", %{"id" => client_id}, socket) do
    if socket.assigns.client_details && socket.assigns.client_details.status == "connected" do
      # Log for debugging
      require Logger
      Logger.debug("Attempting to refresh printers for client: #{client_id}")

      # Use ConnectionManager to properly request printers
      case ConnectionManager.request_printers(client_id) do
        {:ok, printers} ->
          Logger.debug("Received printers for client #{client_id}: #{length(printers)} printers")

          # Update the client details with the new printer list
          client_details = if socket.assigns.client_details do
            Map.put(socket.assigns.client_details, :printers, printers)
          else
            socket.assigns.client_details
          end

          {:noreply,
           socket
           |> assign(:client_details, client_details)
           |> assign(:fetching_printers, false)
           |> put_flash(:info, "Refreshed printer list (#{length(printers)} printers)")}

        {:error, :not_connected} ->
          Logger.warning("Client #{client_id} not connected via WebSocket")

          {:noreply,
           socket
           |> assign(:fetching_printers, false)
           |> put_flash(:error, "Desktop client is not connected. Please ensure the desktop app is running and connected.")}

        {:error, :timeout} ->
          Logger.warning("Timeout waiting for printers from client #{client_id}")

          {:noreply,
           socket
           |> assign(:fetching_printers, false)
           |> put_flash(:error, "Timeout waiting for printer list. Client may not be responding.")}

        {:error, reason} ->
          Logger.error("Failed to get printers for client #{client_id}: #{inspect(reason)}")

          {:noreply,
           socket
           |> assign(:fetching_printers, false)
           |> put_flash(:error, "Failed to get printer list: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Client status shows as disconnected")}
    end
  end
  
  @impl true
  def handle_event("test_print_with_printer", %{"client-id" => client_id, "printer-id" => printer_id, "printer-name" => printer_name}, socket) do
    require Logger
    Logger.info("Quick test print requested for client #{client_id}, printer #{printer_id}")
    
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))
    
    if client && Clients.user_has_access?(socket.assigns.current_scope.user.id, client.id) do
      # Create default test content (plain text) - desktop converts to PDF
      content = """
      Test Print from GoPrint\n
      Client: #{client.api_name || client_id}\n
      Printer: #{printer_name}\n
      Date: #{DateTime.utc_now() |> DateTime.to_string()}\n
      \n
      ✓ Connection successful\n
      ✓ Print test successful\n
      \n
      This is a test page to verify printer connectivity.
      """
      
      case PrintJobs.create_print_job(%{
        client_id: client.id,
        user_id: socket.assigns.current_scope.user.id,
        printer_id: printer_id,
        paper_size: "A4",
        content: content,
        options: %{mime: "text/plain", filename: "test.txt", document_name: "Test Print"}
      }) do
        {:ok, print_job} ->
          Logger.info("Quick print job created: #{print_job.job_id} for printer #{printer_id}")
          
          # Send print job to client via WebSocket
          # Format job for desktop client (exclude associations)
          # Desktop app expects: content (base64) and options.mime
          job_for_desktop = %{
            job_id: print_job.job_id,
            printer_id: print_job.printer_id,
            content: Base.encode64(print_job.content || ""),
            options: print_job.options
          }
          
          Phoenix.PubSub.broadcast(
            GoprintRegistry.PubSub,
            "desktop:#{client.id}",
            {:print_job, job_for_desktop}
          )
          
          Logger.info("Print job #{print_job.job_id} broadcast to desktop:#{client.id}")
          
          {:noreply,
           socket
           |> put_flash(:info, "Test print sent to #{printer_name}! Job ID: #{print_job.job_id}")}
      
        {:error, changeset} ->
          Logger.error("Failed to create quick print job: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to send test print")}
      end
    else
      {:noreply, put_flash(socket, :error, "Client not found or access denied")}
    end
  end
  
  @impl true
  def handle_event("open_test_print", %{"id" => client_id}, socket) do
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))
    
    {:noreply,
     socket
     |> assign(:show_test_print_modal, true)
     |> assign(:selected_client, client)}
  end
  
  @impl true
  def handle_event("close_test_print", _, socket) do
    {:noreply,
     socket
     |> assign(:show_test_print_modal, false)
     |> assign(:selected_client, nil)
     |> assign(:print_job_status, nil)}
  end
  
  @impl true
  def handle_event("toggle_ip_details", %{"id" => client_id}, socket) do
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))
    # Load IP addresses for the client
    client_with_ips = if client do
      %{client | ip_addresses: Clients.get_client_ip_addresses(client_id)}
    else
      nil
    end
    
    {:noreply,
     socket
     |> assign(:show_ip_modal, true)
     |> assign(:selected_client, client_with_ips)}
  end
  
  @impl true
  def handle_event("close_ip_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_ip_modal, false)
     |> assign(:selected_client, nil)}
  end
  
  @impl true
  def handle_event("validate_test_print", %{"test_print" => params}, socket) do
    {:noreply, assign(socket, :test_print_form, to_form(params))}
  end
  
  @impl true
  def handle_event("submit_test_print", %{"test_print" => params}, socket) do
    client = socket.assigns.selected_client
    
    require Logger
    Logger.info("Test print requested for client #{client.id}, printer: #{params["printer_id"]}")
    
    # Check if user has access to this client
    if Clients.user_has_access?(socket.assigns.current_scope.user.id, client.id) do
      case PrintJobs.create_print_job(%{
        client_id: client.id,
        user_id: socket.assigns.current_scope.user.id,
        printer_id: params["printer_id"],
        paper_size: params["paper_size"],
        content: params["content"],
        options: %{mime: "text/plain", filename: "test.txt", document_name: "Test Print"}
      }) do
        {:ok, print_job} ->
          Logger.info("Print job created: #{print_job.job_id} for client #{client.id}")
          
          # Send print job to client via WebSocket
          # Format job for desktop client (exclude associations)
          # Desktop app expects: content (base64) and options.mime
          job_for_desktop = %{
            job_id: print_job.job_id,
            printer_id: print_job.printer_id,
            content: Base.encode64(print_job.content || ""),
            options: print_job.options
          }
          
          Phoenix.PubSub.broadcast(
            GoprintRegistry.PubSub,
            "desktop:#{client.id}",
            {:print_job, job_for_desktop}
          )
          
          Logger.info("Print job #{print_job.job_id} broadcast to desktop:#{client.id}")
        
          {:noreply,
           socket
           |> put_flash(:info, "Test print sent successfully! Job ID: #{print_job.job_id}")
           |> assign(:print_job_status, print_job)
           |> assign(:show_test_print_modal, false)}
      
        {:error, changeset} ->
          Logger.error("Failed to create print job: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to send test print")}
      end
    else
      Logger.warning("User #{socket.assigns.current_scope.user.id} doesn't have access to client #{client.id}")
      {:noreply, put_flash(socket, :error, "You don't have access to this client")}
    end
  end
  
  @impl true
  def handle_info({:client_connected, client}, socket) do
    clients = update_client_in_list(socket.assigns.clients, client)
    {:noreply, assign(socket, :clients, clients)}
  end
  
  @impl true
  def handle_info({:client_disconnected, client_id}, socket) do
    clients = Enum.map(socket.assigns.clients, fn c ->
      if c.id == client_id, do: %{c | status: "disconnected"}, else: c
    end)
    {:noreply, assign(socket, :clients, clients)}
  end
  
  @impl true
  def handle_info({:printers_updated, client_id, printers}, socket) do
    clients = Enum.map(socket.assigns.clients, fn c ->
      if c.id == client_id, do: %{c | printers: printers}, else: c
    end)
    
    # Update client details if modal is open
    client_details = if socket.assigns.client_details && socket.assigns.client_details.id == client_id do
      %{socket.assigns.client_details | printers: printers}
    else
      socket.assigns.client_details
    end
    
    {:noreply,
     socket
     |> assign(:clients, clients)
     |> assign(:client_details, client_details)
     |> assign(:fetching_printers, false)}
  end
  
  @impl true
  def handle_info({:print_job_status, job_id, status, details}, socket) do
    if socket.assigns.print_job_status && socket.assigns.print_job_status.job_id == job_id do
      updated_job = %{socket.assigns.print_job_status | status: status, details: details}
      {:noreply, assign(socket, :print_job_status, updated_job)}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_info({:printer_fetch_timeout, client_id}, socket) do
    if socket.assigns.fetching_printers do
      Phoenix.PubSub.unsubscribe(GoprintRegistry.PubSub, "printer_refresh:#{client_id}")
      {:noreply,
       socket
       |> assign(:fetching_printers, false)
       |> put_flash(:error, "Timeout waiting for printer list. Client may not be responding.")}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_info(:refresh_connections, socket) do
    # Refresh connection status from ConnectionManager
    clients = load_clients_with_connection_status(socket.assigns.current_scope.user.id)
    
    # Only update if there are changes to avoid unnecessary re-renders
    if clients != socket.assigns.clients do
      {:noreply, assign(socket, :clients, clients)}
    else
      {:noreply, socket}
    end
  end
  
  defp update_client_in_list(clients, updated_client) do
    Enum.map(clients, fn client ->
      if client.id == updated_client.id, do: updated_client, else: client
    end)
  end
  
  defp load_clients_with_connection_status(user_id) do
    # Get clients from database
    db_clients = Clients.list_clients_for_user(user_id)
    
    # Get active WebSocket connections
    ws_connections = ConnectionManager.list_connections()
    ws_client_ids = Enum.map(ws_connections, fn {client_id, _} -> client_id end)
    
    # Update status based on actual WebSocket connections
    Enum.map(db_clients, fn client ->
      Map.from_struct(client)
      |> Map.put(:status, if(client.id in ws_client_ids, do: "connected", else: "disconnected"))
      |> Map.put(:ws_connected, client.id in ws_client_ids)
    end)
  end
end
