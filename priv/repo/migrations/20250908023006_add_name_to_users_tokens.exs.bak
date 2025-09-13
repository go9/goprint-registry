defmodule GoprintRegistry.Repo.Migrations.AddNameToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :name, :string
      add :last_used_at, :utc_datetime
    end

    create index(:users_tokens, [:user_id, :context])
  end
end