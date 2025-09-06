defmodule GoprintRegistry.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, :string, null: false
      add :api_key, :string, null: false
      add :api_name, :string
      add :last_connected_at, :utc_datetime
      add :status, :string, default: "disconnected"
      add :printers, {:array, :map}, default: []
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:clients, [:user_id, :client_id])
    create index(:clients, [:user_id])
    create index(:clients, [:api_key])
    create index(:clients, [:status])
  end
end