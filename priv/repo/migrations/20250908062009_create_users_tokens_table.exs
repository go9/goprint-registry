defmodule GoprintRegistry.Repo.Migrations.CreateUsersTokensTable do
  use Ecto.Migration

  def up do
    # Only create if it doesn't exist
    create_if_not_exists table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create_if_not_exists index(:users_tokens, [:user_id])
    create_if_not_exists unique_index(:users_tokens, [:context, :token])
  end

  def down do
    drop_if_exists table(:users_tokens)
  end
end