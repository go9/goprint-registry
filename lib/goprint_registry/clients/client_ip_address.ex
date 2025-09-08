defmodule GoprintRegistry.Clients.ClientIpAddress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "client_ip_addresses" do
    belongs_to :client, GoprintRegistry.Clients.Client
    field :ip_address, :string
    field :first_seen, :utc_datetime
    field :last_seen, :utc_datetime
    field :connection_count, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(client_ip, attrs) do
    client_ip
    |> cast(attrs, [:client_id, :ip_address, :first_seen, :last_seen, :connection_count])
    |> validate_required([:client_id, :ip_address, :first_seen, :last_seen])
    |> unique_constraint([:client_id, :ip_address])
  end
end