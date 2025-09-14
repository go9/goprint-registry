defmodule GoprintRegistry.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset
  
  @derive {Flop.Schema,
           filterable: [:api_name, :mac_address, :operating_system],
           sortable: [:api_name, :last_connected_at, :inserted_at],
           default_limit: 20}

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "clients" do
    field :api_name, :string
    field :last_connected_at, :utc_datetime
    field :status, :string, default: "disconnected"
    
    # Self-registration fields
    field :mac_address, :string
    field :operating_system, :string
    field :app_version, :string
    field :registered_at, :utc_datetime
    field :client_secret_hash, :string
    
    # Many-to-many relationship with users
    has_many :client_users, GoprintRegistry.Clients.ClientUser
    has_many :users, through: [:client_users, :user]
    has_many :print_jobs, GoprintRegistry.PrintJobs.PrintJob
    has_many :ip_addresses, GoprintRegistry.Clients.ClientIpAddress

    timestamps()
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:api_name, :last_connected_at, :status,
                    :mac_address, :operating_system, :app_version, :registered_at])
    |> validate_required([:mac_address])
    |> validate_inclusion(:status, ["connected", "disconnected"])
    |> unique_constraint(:mac_address)
  end

  def registration_changeset(client, attrs) do
    client
    |> cast(attrs, [:api_name, :mac_address, 
                    :operating_system, :app_version, :registered_at, :client_secret_hash])
    |> validate_required([:mac_address])
    |> put_change(:registered_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> unique_constraint(:mac_address)
  end

  def connection_changeset(client, attrs) do
    client
    |> cast(attrs, [:last_connected_at, :status, :printers])
    |> validate_inclusion(:status, ["connected", "disconnected"])
  end
end