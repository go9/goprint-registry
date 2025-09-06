defmodule GoprintRegistry.Repo.Migrations.CreateDesktopClients do
  use Ecto.Migration

  def change do
    create table(:desktop_clients) do
      add :name, :string, null: false
      add :hostname, :string
      add :api_key_id, references(:api_keys, on_delete: :delete_all), null: false
      add :last_seen_at, :utc_datetime
      add :connected_at, :utc_datetime
      add :printers, :map, default: %{}
      add :status, :string, default: "offline"
      add :ip_address, :string
      add :version, :string

      timestamps(type: :utc_datetime)
    end

    create index(:desktop_clients, [:api_key_id])
    create index(:desktop_clients, [:last_seen_at])
    create index(:desktop_clients, [:status])
  end
end