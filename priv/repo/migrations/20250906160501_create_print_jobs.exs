defmodule GoprintRegistry.Repo.Migrations.CreatePrintJobs do
  use Ecto.Migration

  def change do
    create table(:print_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_id, :string, null: false
      add :printer_id, :string, null: false
      add :content, :text, null: false
      add :paper_size, :string
      add :options, :map, default: %{}
      
      # Server-side status
      add :status, :string, default: "pending"  # pending, sent, acknowledged, completed, failed
      add :status_details, :text
      
      # Client-side status
      add :client_status, :string  # queued, printing, printed, error
      add :client_status_details, :text
      add :client_status_updated_at, :utc_datetime
      
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:print_jobs, [:job_id])
    create index(:print_jobs, [:client_id])
    create index(:print_jobs, [:user_id])
    create index(:print_jobs, [:status])
    create index(:print_jobs, [:client_status])
    create index(:print_jobs, [:inserted_at])
  end
end