defmodule GoprintRegistry.Repo.Migrations.RestructureClientsUsersRelationship do
  use Ecto.Migration

  def change do
    # Drop the foreign key constraint from clients to users
    alter table(:clients) do
      remove :user_id
    end
    
    # Add fields for client self-registration
    alter table(:clients) do
      add :machine_id, :string
      add :machine_name, :string
      add :operating_system, :string
      add :app_version, :string
      add :registered_at, :utc_datetime
    end
    
    # Create join table for many-to-many relationship
    create table(:client_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :added_at, :utc_datetime, null: false
      add :is_active, :boolean, default: true
      add :permissions, :map, default: %{}
      
      timestamps()
    end
    
    create unique_index(:client_users, [:client_id, :user_id])
    create index(:client_users, [:user_id])
    create index(:client_users, [:client_id])
    
    # Update indexes on clients table
    drop_if_exists index(:clients, [:user_id])
    drop_if_exists index(:clients, [:user_id, :client_id])
    create_if_not_exists unique_index(:clients, [:api_key])
    create_if_not_exists index(:clients, [:machine_id])
  end
end