defmodule GoprintRegistryWeb.PrintJobController do
  use GoprintRegistryWeb, :controller
  require Logger
  alias GoprintRegistry.{Clients, PrintJobs, ConnectionManager}

  # POST /api/print_jobs/file
  # Body JSON:
  # {
  #   "client_id": "...", "printer_id": "...",
  #   "data_base64": "...", "mime": "application/pdf",
  #   "filename": "doc.pdf",
  #   "options": { "document_name": "...", "raw": false }
  # }
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
            send_result = ConnectionManager.send_print_job(client_id, Map.from_struct(print_job))
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
  # Body JSON: { "client_id": "...", "printer_id": "..." }
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
