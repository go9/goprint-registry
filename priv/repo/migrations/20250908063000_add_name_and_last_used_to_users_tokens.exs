defmodule GoprintRegistry.Repo.Migrations.AddNameAndLastUsedToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add_if_not_exists :name, :string
      add_if_not_exists :last_used_at, :utc_datetime
    end

    create_if_not_exists index(:users_tokens, [:user_id, :context])
  end
end