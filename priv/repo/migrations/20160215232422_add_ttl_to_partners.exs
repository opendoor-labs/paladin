defmodule Paladin.Repo.Migrations.AddTtlToPartners do
  use Ecto.Migration

  def change do
    alter table(:partners) do
      add :ttl_seconds, :integer, default: 10 * 60
    end
  end
end
