defmodule GoprintRegistry.Repo.Migrations.RemovePrintersFromClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      remove :printers
    end
  end
end
