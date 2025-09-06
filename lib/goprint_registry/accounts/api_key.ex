defmodule GoprintRegistry.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset


  schema "api_keys" do
    field :name, :string
    field :key, :string
    field :secret, :string, virtual: true
    field :secret_hash, :string
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :user, GoprintRegistry.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for a new API key with generated credentials.
  """
  def creation_changeset(attrs) do
    key = generate_key()
    secret = generate_secret()

    %__MODULE__{}
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
    |> put_change(:key, key)
    |> put_change(:secret, secret)
    |> put_change(:secret_hash, hash_secret(secret))
    |> unique_constraint(:key)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Generates a new API key.
  """
  def generate_key do
    "gpr_" <> Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
  end

  @doc """
  Generates a new API secret.
  """
  def generate_secret do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  @doc """
  Hashes an API secret.
  """
  def hash_secret(secret) do
    :crypto.hash(:sha256, secret)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies an API secret against its hash.
  """
  def verify_secret(secret, hash) when is_binary(secret) and is_binary(hash) do
    hash_secret(secret) == hash
  end

  def verify_secret(_, _), do: false

  @doc """
  Checks if the API key is revoked.
  """
  def revoked?(%__MODULE__{revoked_at: nil}), do: false
  def revoked?(%__MODULE__{}), do: true
end