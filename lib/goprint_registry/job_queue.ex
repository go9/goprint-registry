defmodule GoprintRegistry.JobQueue do
  @moduledoc """
  Manages print job queue and routing to desktop clients
  """
  use GenServer
  require Logger

  @table_name :print_jobs

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def create_job(developer_api_key, client_id, printer_id, content, options \\ %{}) do
    job_id = generate_job_id()
    
    job = %{
      id: job_id,
      developer_api_key: developer_api_key,
      client_id: client_id,
      printer_id: printer_id,
      content: content,
      options: options,
      status: "pending",
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    
    GenServer.call(__MODULE__, {:create_job, job})
  end

  # New: create a file-based job where `content` is base64 bytes and
  # MIME/filename are provided via options. Backwards compatible because
  # we still store the bytes in `content` and metadata in `options`.
  def create_file_job(developer_api_key, client_id, printer_id, data_base64, mime, filename, options \\ %{}) do
    opts = options |> Map.put("mime", mime) |> Map.put("filename", filename)
    create_job(developer_api_key, client_id, printer_id, data_base64, opts)
  end

  def update_job_status(job_id, status, details \\ nil) do
    GenServer.cast(__MODULE__, {:update_status, job_id, status, details})
  end

  def get_job(job_id) do
    case :ets.lookup(@table_name, job_id) do
      [{^job_id, job}] -> {:ok, job}
      [] -> {:error, :not_found}
    end
  end

  def list_jobs(filters \\ %{}) do
    jobs = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, job} -> job end)
    
    # Apply filters
    jobs = if Map.has_key?(filters, :developer_api_key) do
      Enum.filter(jobs, &(&1.developer_api_key == filters.developer_api_key))
    else
      jobs
    end
    
    jobs = if Map.has_key?(filters, :client_id) do
      Enum.filter(jobs, &(&1.client_id == filters.client_id))
    else
      jobs
    end
    
    jobs = if Map.has_key?(filters, :status) do
      Enum.filter(jobs, &(&1.status == filters.status))
    else
      jobs
    end
    
    Enum.sort_by(jobs, & &1.created_at, {:desc, DateTime})
  end

  def notify_job_status(job_id, status, details) do
    # This would notify the developer via webhook or other mechanism
    # For now, just log it
    Logger.info("Job #{job_id} status update: #{status} - #{inspect(details)}")
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table])
    Logger.info("JobQueue started")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_job, job}, _from, state) do
    # Store the job
    :ets.insert(@table_name, {job.id, job})
    
    # Send to desktop client (only send the formatted data, not the full job struct)
    case GoprintRegistry.ConnectionManager.send_print_job(job.client_id, format_job_for_desktop(job)) do
      :ok ->
        Logger.info("Print job #{job.id} sent to client #{job.client_id}")
        {:reply, {:ok, job.id}, state}
      {:error, reason} ->
        # Update job status to failed
        failed_job = Map.merge(job, %{
          status: "failed",
          error: reason,
          updated_at: DateTime.utc_now()
        })
        :ets.insert(@table_name, {job.id, failed_job})
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:update_status, job_id, status, details}, state) do
    case :ets.lookup(@table_name, job_id) do
      [{^job_id, job}] ->
        updated_job = Map.merge(job, %{
          status: status,
          details: details,
          updated_at: DateTime.utc_now()
        })
        :ets.insert(@table_name, {job_id, updated_job})
        Logger.info("Job #{job_id} status updated to #{status}")
      [] ->
        Logger.warning("Attempted to update status for unknown job #{job_id}")
    end
    
    {:noreply, state}
  end

  # Private functions

  defp generate_job_id do
    "job_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp format_job_for_desktop(job) do
    %{
      job_id: job.id,
      printer_id: job.printer_id,
      content: job.content,
      options: job.options
    }
  end
end
