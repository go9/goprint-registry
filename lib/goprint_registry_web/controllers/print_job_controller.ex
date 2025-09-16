defmodule GoprintRegistryWeb.PrintJobController do
  use GoprintRegistryWeb, :controller
  
  require Logger
  alias GoprintRegistry.Services.PrintJobService

  # GET /api/print_jobs
  def list(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        {jobs, total} = PrintJobService.list_user_jobs(user.id, params)
        
        json(conn, %{
          jobs: jobs,
          total: total,
          limit: parse_limit(params["limit"]),
          offset: parse_offset(params["offset"])
        })
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # GET /api/print_jobs/:job_id
  def show(conn, %{"job_id" => job_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobService.get_user_job(user.id, job_id) do
          {:ok, job} ->
            json(conn, job)
            
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{success: false, error: "Print job not found"})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # DELETE /api/print_jobs/:job_id
  def cancel(conn, %{"job_id" => job_id}) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobService.cancel_job(user.id, job_id) do
          {:ok, response} ->
            json(conn, response)
            
          {:error, :not_found, message} ->
            conn
            |> put_status(:not_found)
            |> json(%{success: false, error: message})
            
          {:error, :conflict, message} ->
            conn
            |> put_status(:conflict)
            |> json(%{success: false, error: message})
            
          _ ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "Failed to cancel print job"})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end
  
  # POST /api/print_jobs/file
  def create_file(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobService.create_from_file(user, params) do
          {:ok, response} ->
            conn
            |> put_status(:created)
            |> json(response)
            
          {:error, {:missing_field, field}} ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "missing_field", field: field})
            
          {:error, :forbidden, message} ->
            conn
            |> put_status(:forbidden)
            |> json(%{success: false, error: message})
            
          {:error, :bad_request, message} ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: message})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end

  # POST /api/print_jobs/test
  def create_test(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        case PrintJobService.create_test_print(user, params) do
          {:ok, response} ->
            conn
            |> put_status(:created)
            |> json(response)
            
          {:error, {:missing_field, field}} ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "missing_field", field: field})
            
          {:error, :forbidden, message} ->
            conn
            |> put_status(:forbidden)
            |> json(%{success: false, error: message})
            
          {:error, :bad_request, message} ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: message})
        end
        
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "unauthenticated"})
    end
  end

  # Private functions
  
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
end