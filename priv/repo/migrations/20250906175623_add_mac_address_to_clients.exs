defmodule GoprintRegistry.Repo.Migrations.AddMacAddressToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add_if_not_exists :mac_address, :string
      add_if_not_exists :operating_system, :string
      add_if_not_exists :app_version, :string
      add_if_not_exists :registered_at, :utc_datetime
    end

    # Create unique index on mac_address if it doesn't exist
    create_if_not_exists unique_index(:clients, [:mac_address])
    
    # Remove old columns if they exist
    alter table(:clients) do
      remove_if_exists :api_key, :string
      remove_if_exists :client_id, :string
      remove_if_exists :machine_name, :string
      remove_if_exists :machine_id, :string
    end
  end
end