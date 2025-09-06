defmodule GoprintRegistry.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "clients" do
    field :client_id, :string
    field :api_key, :string
    field :api_name, :string
    field :last_connected_at, :utc_datetime
    field :status, :string, default: "disconnected"
    field :printers, {:array, :map}, default: []
    
    belongs_to :user, GoprintRegistry.Accounts.User
    has_many :print_jobs, GoprintRegistry.PrintJobs.PrintJob

    timestamps()
  end

  @doc false
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:client_id, :api_key, :api_name, :last_connected_at, :status, :printers, :user_id])
    |> validate_required([:client_id, :api_key, :user_id])
    |> validate_inclusion(:status, ["connected", "disconnected"])
    |> unique_constraint([:user_id, :client_id])
  end

  def connection_changeset(client, attrs) do
    client
    |> cast(attrs, [:last_connected_at, :status, :printers])
    |> validate_inclusion(:status, ["connected", "disconnected"])
  end
end