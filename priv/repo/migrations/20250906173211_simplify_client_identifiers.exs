defmodule GoprintRegistry.Repo.Migrations.SimplifyClientIdentifiers do
  use Ecto.Migration

  def change do
    # Remove the redundant fields
    alter table(:clients) do
      remove :client_id
      remove :api_key
    end
    
    # Remove the unique constraints
    drop_if_exists unique_index(:clients, :client_id)
    drop_if_exists unique_index(:clients, :api_key)
    
    # Add unique constraint on machine_id to prevent duplicate registrations
    create_if_not_exists unique_index(:clients, :machine_id)
  end
end