defmodule GoprintRegistry.Services.PrinterService do
  @moduledoc """
  Service module for managing printer operations and capabilities.
  Handles printer discovery, capability queries, and paper size management.
  """

  alias GoprintRegistry.{Clients, ConnectionManager}
  require Logger

  @doc """
  Fetches the list of printers from a connected desktop client.
  Returns {:ok, printers} or {:error, reason}
  """
  def get_printers(client_id) do
    with {:ok, _client} <- validate_client_exists(client_id),
         {:ok, printers} <- fetch_printers_from_client(client_id) do
      {:ok, format_printer_response(printers)}
    end
  end

  @doc """
  Gets printer capabilities including supported paper sizes.
  This replaces hardcoded paper size lists.
  """
  def get_printer_capabilities(client_id, printer_id) do
    with {:ok, _client} <- validate_client_exists(client_id),
         {:ok, capabilities} <- fetch_printer_capabilities(client_id, printer_id) do
      {:ok, capabilities}
    end
  end

  @doc """
  Gets all supported paper sizes for a specific printer.
  Returns dynamic list from the actual printer only.
  """
  def get_paper_sizes(client_id, printer_id) do
    case get_printer_capabilities(client_id, printer_id) do
      {:ok, %{"paper_sizes" => sizes}} when is_list(sizes) ->
        {:ok, sizes}
      
      {:ok, _} ->
        # Printer doesn't report paper sizes
        {:error, :paper_sizes_not_available}
      
      error ->
        error
    end
  end

  @doc """
  Sends a test print to verify printer connectivity.
  """
  def send_test_print(client_id, printer_id, options \\ %{}) do
    with {:ok, _client} <- validate_client_exists(client_id) do
      # Check if client is connected
      case ConnectionManager.get_client(client_id) do
        {:ok, _} ->
          job_id = Ecto.UUID.generate()
          
          print_job = %{
            id: job_id,
            printer_id: printer_id,
            content: build_test_content(client_id, printer_id),
            options: Map.merge(%{
              mime: "text/plain",
              filename: "test.txt",
              document_name: "GoPrint Test",
              page_size: Map.get(options, "paper_size")
            }, options)
          }
          
          # Broadcast to the specific client's channel
          GoprintRegistryWeb.Endpoint.broadcast!(
            "desktop:#{client_id}",
            "print_job",
            print_job
          )
          
          {:ok, job_id}
        
        {:error, :not_found} ->
          {:error, :service_unavailable, "Client is not connected"}
      end
    end
  end

  # Private functions

  defp validate_client_exists(client_id) do
    case Clients.get_client(client_id) do
      nil -> {:error, :not_found, "Client not found"}
      client -> {:ok, client}
    end
  end

  defp fetch_printers_from_client(client_id) do
    case ConnectionManager.request_printers(client_id) do
      {:ok, printers} ->
        {:ok, printers}
      
      {:error, :not_connected} ->
        {:error, :service_unavailable, "Client not connected"}
      
      {:error, :timeout} ->
        {:error, :request_timeout, "Desktop client did not respond in time"}
      
      error ->
        error
    end
  end

  defp fetch_printer_capabilities(client_id, printer_id) do
    # Request capabilities from desktop client via WebSocket
    case ConnectionManager.request_printer_capabilities(client_id, printer_id) do
      {:ok, capabilities} ->
        {:ok, capabilities}
      
      {:error, :not_connected} ->
        {:error, :service_unavailable, "Client not connected"}
      
      {:error, :timeout} ->
        {:error, :request_timeout, "Failed to get printer capabilities"}
      
      {:error, :not_supported} ->
        # Desktop client doesn't support capability query yet
        {:ok, get_default_capabilities()}
      
      error ->
        error
    end
  end

  defp format_printer_response(printers) do
    %{
      success: true,
      printers: printers,
      source: "real_time"
    }
  end

  defp build_test_content(client_id, printer_id) do
    client = Clients.get_client(client_id)
    client_label = if client, do: client.api_name || client_id, else: client_id
    
    """
    Test Print from GoPrint
    
    Client: #{client_label}
    Printer: #{printer_id}
    Date: #{DateTime.utc_now() |> DateTime.to_string()}
    
    ✓ Connection successful
    ✓ Print test successful
    
    This is a test page to verify printer connectivity.
    """
  end

  defp get_default_capabilities do
    # Return empty capabilities - we can't assume what the printer supports
    %{
      "paper_sizes" => [],
      "features" => [],
      "status" => "unknown"
    }
  end
end