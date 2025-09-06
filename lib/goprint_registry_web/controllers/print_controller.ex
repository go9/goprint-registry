defmodule GoprintRegistryWeb.PrintController do
  use GoprintRegistryWeb, :controller
  require Logger

  alias GoprintRegistry.{JobQueue, ConnectionManager}

  @doc """
  Submit a print job
  """
  def print(conn, %{"client_id" => client_id, "printer_id" => printer_id, "content" => content} = params) do
    # Get API key from Authorization header
    api_key = get_api_key(conn)
    
    if api_key do
      # Check if desktop client is connected
      case ConnectionManager.get_desktop_client(client_id) do
        {:ok, client} ->
          # Check if printer is available
          if printer_available?(client, printer_id) do
            options = params["options"] || %{}
            
            case JobQueue.create_job(api_key, client_id, printer_id, content, options) do
              {:ok, job_id} ->
                json(conn, %{
                  success: true,
                  job_id: job_id,
                  message: "Print job submitted successfully"
                })
              
              {:error, reason} ->
                conn
                |> put_status(:internal_server_error)
                |> json(%{error: "Failed to create job: #{reason}"})
            end
          else
            conn
            |> put_status(:not_found)
            |> json(%{error: "Printer not found or unavailable"})
          end
        
        {:error, _} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Desktop client not connected"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "API key required"})
    end
  end

  @doc """
  Submit multiple print jobs
  """
  def bulk_print(conn, %{"jobs" => jobs}) when is_list(jobs) do
    api_key = get_api_key(conn)
    
    if api_key do
      results = Enum.map(jobs, fn job ->
        client_id = job["client_id"]
        printer_id = job["printer_id"]
        content = job["content"]
        options = job["options"] || %{}
        
        case ConnectionManager.get_desktop_client(client_id) do
          {:ok, client} ->
            if printer_available?(client, printer_id) do
              case JobQueue.create_job(api_key, client_id, printer_id, content, options) do
                {:ok, job_id} ->
                  %{success: true, job_id: job_id}
                {:error, reason} ->
                  %{success: false, error: reason}
              end
            else
              %{success: false, error: "Printer not available"}
            end
          {:error, _} ->
            %{success: false, error: "Client not connected"}
        end
      end)
      
      # Separate successful and failed jobs
      successful = Enum.filter(results, & &1.success)
      failed = Enum.reject(results, & &1.success)
      
      json(conn, %{
        total: length(jobs),
        successful: length(successful),
        failed: length(failed),
        results: results
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "API key required"})
    end
  end

  @doc """
  Get job status
  """
  def job_status(conn, %{"job_id" => job_id}) do
    api_key = get_api_key(conn)
    
    if api_key do
      case JobQueue.get_job(job_id) do
        {:ok, job} ->
          # Verify the API key matches
          if job.developer_api_key == api_key do
            json(conn, %{
              job_id: job.id,
              status: job.status,
              created_at: job.created_at,
              updated_at: job.updated_at,
              details: Map.get(job, :details)
            })
          else
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Access denied"})
          end
        
        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Job not found"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "API key required"})
    end
  end

  @doc """
  List jobs for developer
  """
  def list_jobs(conn, params) do
    api_key = get_api_key(conn)
    
    if api_key do
      filters = %{developer_api_key: api_key}
      
      # Add optional filters
      filters = if params["client_id"], do: Map.put(filters, :client_id, params["client_id"]), else: filters
      filters = if params["status"], do: Map.put(filters, :status, params["status"]), else: filters
      
      jobs = JobQueue.list_jobs(filters)
      |> Enum.map(fn job ->
        %{
          job_id: job.id,
          client_id: job.client_id,
          printer_id: job.printer_id,
          status: job.status,
          created_at: job.created_at,
          updated_at: job.updated_at
        }
      end)
      
      json(conn, %{jobs: jobs})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "API key required"})
    end
  end

  @doc """
  List connected clients and their printers
  """
  def list_clients(conn, _params) do
    api_key = get_api_key(conn)
    
    if api_key do
      clients = ConnectionManager.list_connected_clients()
      |> Enum.map(fn client ->
        %{
          client_id: client.id,
          connected_at: client.connected_at,
          printers: Enum.map(client.printers, fn printer ->
            %{
              id: printer["id"],
              name: printer["name"],
              status: printer["status"]
            }
          end)
        }
      end)
      
      json(conn, %{clients: clients})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "API key required"})
    end
  end

  # Private functions

  defp get_api_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp printer_available?(client, printer_id) do
    Enum.any?(client.printers, fn p -> 
      p["id"] == printer_id && p["status"] == "online"
    end)
  end
end