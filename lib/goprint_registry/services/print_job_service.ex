defmodule GoprintRegistry.Services.PrintJobService do
  @moduledoc """
  Service module for managing print jobs.
  Handles job creation, submission, status tracking, and cancellation.
  """

  alias GoprintRegistry.{Clients, PrintJobs, ConnectionManager}
  require Logger

  @doc """
  Creates and sends a print job from file data.
  """
  def create_from_file(user, params) do
    with {:ok, client_id} <- fetch_param(params, "client_id"),
         {:ok, printer_id} <- fetch_param(params, "printer_id"),
         {:ok, data_b64} <- fetch_param(params, "data_base64"),
         {:ok, mime} <- fetch_param(params, "mime"),
         :ok <- verify_client_access(user.id, client_id) do
      
      require Logger
      Logger.info("PrintJobService: Creating print job", 
        client_id: client_id, 
        printer_id: printer_id,
        user_id: user.id
      )
      
      create_and_send_job(user.id, client_id, printer_id, data_b64, mime, params)
    end
  end

  @doc """
  Creates and sends a test print job.
  """
  def create_test_print(user, params) do
    with {:ok, client_id} <- fetch_param(params, "client_id"),
         {:ok, printer_id} <- fetch_param(params, "printer_id"),
         :ok <- verify_client_access(user.id, client_id) do
      
      content = generate_test_content(client_id, printer_id)
      
      attrs = %{
        client_id: client_id,
        user_id: user.id,
        printer_id: printer_id,
        content: content,
        options: %{
          mime: "text/plain",
          filename: "test.txt",
          document_name: "Test Print"
        }
      }
      
      create_and_dispatch_job(attrs)
    end
  end

  @doc """
  Lists print jobs for a user with filtering options.
  """
  def list_user_jobs(user_id, params \\ %{}) do
    filters = %{
      client_id: params["client_id"],
      status: params["status"],
      limit: parse_limit(params["limit"]),
      offset: parse_offset(params["offset"])
    }
    
    {jobs, total} = PrintJobs.list_user_print_jobs(user_id, filters)
    
    {format_jobs(jobs), total}
  end

  @doc """
  Gets a specific print job if the user has access.
  """
  def get_user_job(user_id, job_id) do
    case PrintJobs.get_user_print_job(user_id, job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, format_job(job)}
    end
  end

  @doc """
  Cancels a print job if possible.
  """
  def cancel_job(user_id, job_id) do
    with {:ok, job} <- get_job_for_cancellation(user_id, job_id),
         :ok <- verify_cancellable(job),
         {:ok, _} <- PrintJobs.cancel_print_job(job) do
      {:ok, %{success: true, message: "Print job cancelled"}}
    end
  end

  # Private functions

  defp fetch_param(params, key) do
    case Map.get(params, key) do
      nil -> {:error, {:missing_field, key}}
      "" -> {:error, {:missing_field, key}}
      value -> {:ok, value}
    end
  end

  defp verify_client_access(user_id, client_id) do
    if Clients.user_has_access?(user_id, client_id) do
      :ok
    else
      {:error, :forbidden, "Access denied"}
    end
  end

  defp create_and_send_job(user_id, client_id, printer_id, data_b64, mime, params) do
    filename = Map.get(params, "filename") || infer_filename(mime)
    options = Map.get(params, "options", %{})
    options = Map.merge(%{"mime" => mime, "filename" => filename}, options)
    
    attrs = %{
      client_id: client_id,
      user_id: user_id,
      printer_id: printer_id,
      paper_size: Map.get(options, "page_size"),
      content: data_b64,
      options: options
    }
    
    create_and_dispatch_job(attrs)
  end

  defp create_and_dispatch_job(attrs) do
    case PrintJobs.create_print_job(attrs) do
      {:ok, print_job} ->
        require Logger
        Logger.info("Print job created in database", 
          job_id: print_job.job_id,
          client_id: print_job.client_id,
          printer_id: print_job.printer_id
        )
        
        status = dispatch_to_client(print_job)
        
        Logger.info("Print job dispatch completed", 
          job_id: print_job.job_id,
          status: status
        )
        
        {:ok, %{
          success: true,
          job_id: print_job.job_id,
          status: status
        }}
      
      {:error, changeset} ->
        require Logger
        Logger.error("Failed to create print job: #{inspect(changeset.errors)}")
        {:error, :bad_request, "Invalid request: #{inspect(changeset.errors)}"}
    end
  end

  defp dispatch_to_client(print_job) do
    job_data = %{
      job_id: print_job.job_id,
      printer_id: print_job.printer_id,
      content: print_job.content,
      options: print_job.options
    }
    
    require Logger
    Logger.info("Dispatching print job to client", client_id: print_job.client_id, job_data: job_data)
    
    case ConnectionManager.send_print_job(print_job.client_id, job_data) do
      :ok -> 
        # Mark DB job as 'sent'
        _ = GoprintRegistry.PrintJobs.update_job_status(print_job, "sent")
        Logger.info("Print job sent successfully to client")
        "sent"
      {:error, reason} -> 
        Logger.warning("Print job queued, client not connected", reason: reason)
        "queued"
    end
  end

  defp get_job_for_cancellation(user_id, job_id) do
    case PrintJobs.get_user_print_job(user_id, job_id) do
      nil -> {:error, :not_found, "Print job not found"}
      job -> {:ok, job}
    end
  end

  defp verify_cancellable(%{status: status}) when status in ["completed", "cancelled", "failed"] do
    {:error, :conflict, "Cannot cancel - job already #{status}"}
  end
  defp verify_cancellable(_job), do: :ok

  defp generate_test_content(client_id, printer_id) do
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

  defp parse_limit(nil), do: 20
  defp parse_limit(limit) when is_binary(limit) do
    limit |> String.to_integer() |> min(100) |> max(1)
  end
  defp parse_limit(limit) when is_integer(limit) do
    limit |> min(100) |> max(1)
  end

  defp parse_offset(nil), do: 0
  defp parse_offset(offset) when is_binary(offset) do
    offset |> String.to_integer() |> max(0)
  end
  defp parse_offset(offset) when is_integer(offset) do
    offset |> max(0)
  end

  defp format_jobs(jobs) do
    Enum.map(jobs, &format_job/1)
  end

  defp format_job(job) do
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
  end

  defp infer_filename("application/pdf"), do: "document.pdf"
  defp infer_filename("image/png"), do: "image.png"
  defp infer_filename("image/jpeg"), do: "image.jpg"
  defp infer_filename("image/gif"), do: "image.gif"
  defp infer_filename("image/tiff"), do: "image.tiff"
  defp infer_filename("image/bmp"), do: "image.bmp"
  defp infer_filename("text/plain"), do: "document.txt"
  defp infer_filename("text/html"), do: "document.html"
  defp infer_filename(_), do: "document.bin"
end
