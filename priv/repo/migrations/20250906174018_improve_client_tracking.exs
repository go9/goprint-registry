defmodule GoprintRegistry.Repo.Migrations.ImproveClientTracking do
  use Ecto.Migration

  def change do
    # Create IP addresses table for tracking client connections
    create table(:client_ip_addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
      add :ip_address, :string, null: false
      add :first_seen, :utc_datetime, null: false
      add :last_seen, :utc_datetime, null: false
      add :connection_count, :integer, default: 1
      
      timestamps()
    end
    
    create index(:client_ip_addresses, [:client_id])
    create unique_index(:client_ip_addresses, [:client_id, :ip_address])
    
    # Update clients table - use MAC address as unique identifier
    alter table(:clients) do
      remove :machine_name
      modify :machine_id, :string, null: false  # This will now store MAC address
    end
    
    # Rename machine_id to mac_address for clarity
    rename table(:clients), :machine_id, to: :mac_address
    
    # Update the unique index
    drop_if_exists unique_index(:clients, :machine_id)
    create unique_index(:clients, :mac_address)
  end
end