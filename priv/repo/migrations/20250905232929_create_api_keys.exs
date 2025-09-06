defmodule GoprintRegistry.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add :name, :string, null: false
      add :key, :string, null: false
      add :secret_hash, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_keys, [:key])
    create index(:api_keys, [:user_id])
    create index(:api_keys, [:revoked_at])
  end
end