defmodule Paladin.Repo.Migrations.AddPermissionsToPartners do
  use Ecto.Migration

  def change do
    alter table(:partners) do
      add :permissions, :map, default: "{}"
    end
  end
end
