defmodule GoprintRegistry.Clients.ClientUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "client_users" do
    belongs_to :client, GoprintRegistry.Clients.Client, type: :binary_id
    belongs_to :user, GoprintRegistry.Accounts.User, foreign_key: :user_id, type: :id
    
    field :added_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :permissions, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(client_user, attrs) do
    client_user
    |> cast(attrs, [:client_id, :user_id, :added_at, :is_active, :permissions])
    |> validate_required([:client_id, :user_id, :added_at])
    |> put_change(:added_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> unique_constraint([:client_id, :user_id])
  end
end
