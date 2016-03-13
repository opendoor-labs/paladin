defmodule Paladin.Repo.Migrations.CreateService do
  use Ecto.Migration

  def change do
    create table(:services) do
      add :name, :string
      add :uuid, :string
      add :short_name, :string
      add :environment, :string
      add :secret, :string

      timestamps
    end

    create index(:services, [:name, :environment], unique: true)
  end
end
