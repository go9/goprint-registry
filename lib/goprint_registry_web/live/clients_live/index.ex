defmodule GoprintRegistryWeb.ClientsLive.Index do
  use GoprintRegistryWeb, :live_view
  
  alias GoprintRegistry.{Clients, PrintJobs}
  alias GoprintRegistry.Clients.Client
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GoprintRegistry.PubSub, "clients:#{socket.assigns.current_scope.user.id}")
    end
    
    clients = Clients.list_clients(socket.assigns.current_scope.user.id)
    
    {:ok,
     socket
     |> assign(:clients, clients)
     |> assign(:page_title, "Clients")
     |> assign(:show_test_print_modal, false)
     |> assign(:selected_client, nil)
     |> assign(:test_print_form, to_form(%{
       "printer_id" => "",
       "paper_size" => "A4",
       "content" => "Test Print from GoPrint Registry\n\nPrinter: [PRINTER_NAME]\nDate: #{DateTime.utc_now() |> DateTime.to_string()}\n\n✓ Connection successful\n✓ Print test successful"
     }))
     |> assign(:filter_status, "all")
     |> assign(:search_query, "")
     |> assign(:add_client_form, to_form(%{"api_key" => ""})), 
     layout: {GoprintRegistryWeb.Layouts, :app}}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_filters(socket, params)}
  end
  
  defp apply_filters(socket, params) do
    status = params["status"] || "all"
    query = params["q"] || ""
    
    clients = Clients.list_clients(socket.assigns.current_scope.user.id)
    
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
      String.contains?(String.downcase(client.api_key || ""), query) ||
      String.contains?(String.downcase(client.api_name || ""), query) ||
      String.contains?(String.downcase(client.client_id || ""), query)
    end)
  end
  
  @impl true
  def handle_event("add_client", %{"add_client" => %{"api_key" => api_key}}, socket) do
    api_key = String.trim(api_key)
    
    if api_key == "" do
      {:noreply, put_flash(socket, :error, "API key cannot be empty")}
    else
      # Extract client_id from API key (assuming format: gp_<client_id>_<random>)
      client_id = case String.split(api_key, "_") do
        ["gp", id | _] -> id
        _ -> api_key  # Use full API key as client_id if format doesn't match
      end
      
      case Clients.create_client(%{
        client_id: client_id,
        api_key: api_key,
        api_name: "Client #{client_id}",
        user_id: socket.assigns.current_scope.user.id,
        status: "disconnected"
      }) do
        {:ok, _client} ->
          clients = Clients.list_clients(socket.assigns.current_scope.user.id)
          {:noreply,
           socket
           |> put_flash(:info, "Client added successfully!")
           |> assign(:clients, clients)
           |> assign(:add_client_form, to_form(%{"api_key" => ""}))}
        
        {:error, changeset} ->
          error_msg = case changeset.errors[:client_id] do
            {"has already been taken", _} -> "This client is already registered"
            _ -> "Failed to add client"
          end
          {:noreply, put_flash(socket, :error, error_msg)}
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
    client = Enum.find(socket.assigns.clients, &(&1.id == client_id))
    
    if client do
      case Clients.delete_client(client) do
        {:ok, _} ->
          clients = Clients.list_clients(socket.assigns.current_scope.user.id)
          {:noreply,
           socket
           |> put_flash(:info, "Client removed successfully")
           |> assign(:clients, clients)}
        
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove client")}
      end
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    params = %{"status" => status, "q" => socket.assigns.search_query}
    {:noreply, push_patch(socket, to: ~p"/clients?#{params}")}
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
  def handle_event("validate_test_print", %{"test_print" => params}, socket) do
    {:noreply, assign(socket, :test_print_form, to_form(params))}
  end
  
  @impl true
  def handle_event("submit_test_print", %{"test_print" => params}, socket) do
    client = socket.assigns.selected_client
    
    case PrintJobs.create_print_job(%{
      client_id: client.id,
      user_id: socket.assigns.current_scope.user.id,
      printer_id: params["printer_id"],
      paper_size: params["paper_size"],
      content: params["content"]
    }) do
      {:ok, print_job} ->
        # Send print job to client via WebSocket
        Phoenix.PubSub.broadcast(
          GoprintRegistry.PubSub,
          "desktop:#{client.client_id}",
          {:print_job, print_job}
        )
        
        {:noreply,
         socket
         |> put_flash(:info, "Test print sent successfully!")
         |> assign(:print_job_status, print_job)
         |> assign(:show_test_print_modal, false)}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send test print")}
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
      if c.client_id == client_id, do: %{c | status: "disconnected"}, else: c
    end)
    {:noreply, assign(socket, :clients, clients)}
  end
  
  @impl true
  def handle_info({:printers_updated, client_id, printers}, socket) do
    clients = Enum.map(socket.assigns.clients, fn c ->
      if c.client_id == client_id, do: %{c | printers: printers}, else: c
    end)
    {:noreply, assign(socket, :clients, clients)}
  end
  
  defp update_client_in_list(clients, updated_client) do
    Enum.map(clients, fn client ->
      if client.id == updated_client.id, do: updated_client, else: client
    end)
  end
end