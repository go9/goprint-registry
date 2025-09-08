defmodule GoprintRegistry.PrintJobs do
  @moduledoc """
  The PrintJobs context.
  """

  import Ecto.Query, warn: false
  alias GoprintRegistry.Repo
  alias GoprintRegistry.PrintJobs.PrintJob

  @doc """
  Returns the list of print_jobs for a user.
  """
  def list_print_jobs(user_id) do
    PrintJob
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> preload(:client)
    |> Repo.all()
  end

  @doc """
  Returns the list of print_jobs for a client.
  """
  def list_client_print_jobs(client_id) do
    PrintJob
    |> where(client_id: ^client_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single print_job.
  """
  def get_print_job!(id), do: Repo.get!(PrintJob, id) |> Repo.preload(:client)

  def get_print_job(id), do: Repo.get(PrintJob, id) |> Repo.preload(:client)

  def get_print_job_by_job_id(job_id) do
    PrintJob
    |> where(job_id: ^job_id)
    |> preload(:client)
    |> Repo.one()
  end

  @doc """
  Creates a print_job.
  """
  def create_print_job(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :job_id, generate_job_id())
    
    %PrintJob{}
    |> PrintJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a print_job.
  """
  def update_print_job(%PrintJob{} = print_job, attrs) do
    print_job
    |> PrintJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates print job status.
  """
  def update_job_status(%PrintJob{} = print_job, status, details \\ nil) do
    attrs = %{status: status}
    attrs = if details, do: Map.put(attrs, :status_details, details), else: attrs
    
    print_job
    |> PrintJob.status_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates print job client status.
  """
  def update_job_client_status(%PrintJob{} = print_job, client_status, details \\ nil) do
    attrs = %{
      client_status: client_status,
      client_status_updated_at: DateTime.utc_now()
    }
    attrs = if details, do: Map.put(attrs, :client_status_details, details), else: attrs
    
    print_job
    |> PrintJob.client_status_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a print_job.
  """
  def delete_print_job(%PrintJob{} = print_job) do
    Repo.delete(print_job)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking print_job changes.
  """
  def change_print_job(%PrintJob{} = print_job, attrs \\ %{}) do
    PrintJob.changeset(print_job, attrs)
  end

  @doc """
  List print jobs for a user with filters and pagination.
  Returns a tuple of {jobs, total_count}.
  """
  def list_user_print_jobs(user_id, filters \\ %{}) do
    query = 
      from(p in PrintJob,
        where: p.user_id == ^user_id,
        order_by: [desc: p.inserted_at]
      )
    
    # Apply filters
    query = 
      if filters[:client_id] do
        where(query, [p], p.client_id == ^filters.client_id)
      else
        query
      end
    
    query = 
      if filters[:status] do
        where(query, [p], p.status == ^filters.status)
      else
        query
      end
    
    # Get total count
    total = Repo.aggregate(query, :count, :id)
    
    # Apply pagination
    query = 
      query
      |> limit(^(filters[:limit] || 20))
      |> offset(^(filters[:offset] || 0))
    
    jobs = Repo.all(query)
    {jobs, total}
  end
  
  @doc """
  Get a print job for a specific user by job_id.
  """
  def get_user_print_job(user_id, job_id) do
    PrintJob
    |> where(user_id: ^user_id, job_id: ^job_id)
    |> Repo.one()
  end
  
  @doc """
  Cancel a print job.
  """
  def cancel_print_job(%PrintJob{} = print_job) do
    print_job
    |> PrintJob.changeset(%{status: "cancelled"})
    |> Repo.update()
  end
  
  @doc """
  Get statistics for a client.
  """
  def get_client_statistics(client_id) do
    query = from(p in PrintJob, where: p.client_id == ^client_id)
    
    total = Repo.aggregate(query, :count, :id)
    completed = Repo.aggregate(from(p in query, where: p.status == "completed"), :count, :id)
    failed = Repo.aggregate(from(p in query, where: p.status == "failed"), :count, :id)
    pages = Repo.aggregate(from(p in query, where: p.status == "completed"), :sum, :pages) || 0
    
    %{
      total_jobs: total,
      completed_jobs: completed,
      failed_jobs: failed,
      pages_printed: pages
    }
  end

  defp generate_job_id do
    "pj_" <> :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end