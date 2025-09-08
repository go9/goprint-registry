defmodule GoprintRegistry.Repo.Migrations.AddClientSecretToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add :client_secret_hash, :string
    end

    # Create index for faster lookups during authentication
    create index(:clients, [:id, :client_secret_hash])
  end
end