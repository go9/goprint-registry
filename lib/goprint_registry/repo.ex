defmodule GoprintRegistry.Repo do
  use Ecto.Repo,
    otp_app: :goprint_registry,
    adapter: Ecto.Adapters.Postgres
end