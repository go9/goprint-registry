defmodule GoprintRegistryWeb.PrintJobController do
  use GoprintRegistryWeb, :controller
  
  require Logger
  alias GoprintRegistry.{Clients, PrintJobs, ConnectionManager}

  # GET /api/print_jobs
  # List print jobs for the authenticated user
  def list(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        # Parse query params
        client_id = params["client_id"]
        status = params["status"]
        limit = String.to_integer(params["limit"] || "20") |> min(100) |> max(1)
        offset = String.to_integer(params["offset"] || "0") |> max(0)
        
        # Get print jobs for user with filters
        {jobs, total} = PrintJobs.list_user_print_jobs(user.id, %{
          client_id: client_id,
          status: status,
          limit: limit,
          offset: offset
        })
        
        # Transform jobs to match API spec
        job_data = Enum.map(jobs, fn job ->
          %{
            job_id: job.job_id,
            client_id: job.client_id,
            printer_id: job.printer_id,
            status: job.status,
            paper_size: job.paper_size,
            pages: job.pages,
            created_at: job.inserted_at,
            updated_at: job.updated_at,
            completed_at: job.completed_at,
            error_message: job.error_message,
            options: job.options || %{}
          }
        end)
        
        json(conn, %{
          jobs: job_data,
          total: total,
          limit: limit,
          offset: offset
        })
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # GET /api/print_jobs/:job_id
  # Get details of a specific print job
  def show(conn, %{"job_id" => job_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobs.get_user_print_job(user.id, job_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{success: false, error: "Print job not found"})
            
          job ->
            job_data = %{
              job_id: job.job_id,
              client_id: job.client_id,
              printer_id: job.printer_id,
              status: job.status,
              paper_size: job.paper_size,
              pages: job.pages,
              created_at: job.inserted_at,
              updated_at: job.updated_at,
              completed_at: job.completed_at,
              error_message: job.error_message,
              options: job.options || %{}
            }
            
            json(conn, job_data)
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # DELETE /api/print_jobs/:job_id
  # Cancel a print job
  def cancel(conn, %{"job_id" => job_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobs.get_user_print_job(user.id, job_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{success: false, error: "Print job not found"})
            
          %{status: status} when status in ["completed", "cancelled", "failed"] ->
            conn
            |> put_status(:conflict)
            |> json(%{success: false, error: "Cannot cancel - job already #{status}"})
            
          job ->
            case PrintJobs.cancel_print_job(job) do
              {:ok, _} ->
                json(conn, %{success: true, message: "Print job cancelled"})
                
              _ ->
                conn
                |> put_status(:bad_request)
                |> json(%{success: false, error: "Failed to cancel print job"})
            end
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # POST /api/print_jobs/file
  # Create a print job from file
  def create_file(conn, params) do
    with %{user: user} when not is_nil(user) <- conn.assigns[:current_scope],
         {:ok, client_id} <- fetch_required(params, "client_id"),
         {:ok, printer_id} <- fetch_required(params, "printer_id"),
         {:ok, data_b64} <- fetch_required(params, "data_base64"),
         {:ok, mime} <- fetch_required(params, "mime") do

      unless Clients.user_has_access?(user.id, client_id) do
        conn |> put_status(:forbidden) |> json(%{success: false, error: "access_denied"})
      else
        filename = Map.get(params, "filename") || infer_filename(mime)
        options = Map.get(params, "options", %{})
        options = Map.merge(%{"mime" => mime, "filename" => filename}, options)

        case PrintJobs.create_print_job(%{
          client_id: client_id,
          user_id: user.id,
          printer_id: printer_id,
          paper_size: Map.get(options, "page_size", "A4"),
          content: data_b64,
          options: options
        }) do
          {:ok, print_job} ->
            # Try real-time push to desktop; if not connected, job remains queued
            # Format the job data for the desktop client
            job_data = %{
              job_id: print_job.job_id,
              printer_id: print_job.printer_id,
              content: print_job.content,
              options: print_job.options
            }
            send_result = ConnectionManager.send_print_job(client_id, job_data)
            status = case send_result do
              :ok -> "sent"
              {:error, _} -> "queued"
            end
            conn |> put_status(:created) |> json(%{success: true, job_id: print_job.job_id, status: status})
          {:error, changeset} ->
            Logger.error("create_file_job_failed", errors: inspect(changeset.errors))
            conn |> put_status(:bad_request) |> json(%{success: false, error: "invalid_request", details: inspect(changeset.errors)})
        end
      end
    else
      nil -> conn |> put_status(:unauthorized) |> json(%{success: false, error: "unauthenticated"})
      {:error, {:missing, field}} -> conn |> put_status(:bad_request) |> json(%{success: false, error: "missing_field", field: field})
    end
  end

  # POST /api/print_jobs/test
  # Send a test print
  def create_test(conn, params) do
    with %{user: user} when not is_nil(user) <- conn.assigns[:current_scope],
         {:ok, client_id} <- fetch_required(params, "client_id"),
         {:ok, printer_id} <- fetch_required(params, "printer_id") do

      unless Clients.user_has_access?(user.id, client_id) do
        conn |> put_status(:forbidden) |> json(%{success: false, error: "access_denied"})
      else
        client = Clients.get_client(client_id)
        client_label = if client, do: client.api_name || client_id, else: client_id
        content = [
          "Test Print from GoPrint Registry",
          "",
          "Client: " <> client_label,
          "Printer: " <> printer_id,
          "Date: " <> (DateTime.utc_now() |> DateTime.to_string()),
          "",
          "\u2713 Connection successful",
          "\u2713 Print test successful",
          "",
          "This is a test page to verify printer connectivity."
        ] |> Enum.join("\n")

        attrs = %{
          client_id: client_id,
          user_id: user.id,
          printer_id: printer_id,
          paper_size: "A4",
          content: content,
          options: %{mime: "text/plain", filename: "test.txt", document_name: "Test Print"}
        }

        case PrintJobs.create_print_job(attrs) do
          {:ok, print_job} ->
            send_result = ConnectionManager.send_print_job(client_id, Map.from_struct(print_job))
            status = case send_result do
              :ok -> "sent"
              {:error, _} -> "queued"
            end
            conn |> put_status(:created) |> json(%{success: true, job_id: print_job.job_id, status: status})
          {:error, changeset} ->
            Logger.error("create_test_job_failed", errors: inspect(changeset.errors))
            conn |> put_status(:bad_request) |> json(%{success: false, error: "invalid_request", details: inspect(changeset.errors)})
        end
      end
    else
      nil -> conn |> put_status(:unauthorized) |> json(%{success: false, error: "unauthenticated"})
      {:error, {:missing, field}} -> conn |> put_status(:bad_request) |> json(%{success: false, error: "missing_field", field: field})
    end
  end

  defp infer_filename("application/pdf"), do: "document.pdf"
  defp infer_filename(mime) when is_binary(mime) do
    base = String.replace(mime, "/", ".")
    base <> ".bin"
  end

  defp fetch_required(map, key) do
    case Map.get(map, key) do
      nil -> {:error, {:missing, key}}
      "" -> {:error, {:missing, key}}
      v -> {:ok, v}
    end
  end
end
