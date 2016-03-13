defmodule Paladin.Repo.Migrations.CreatePartner do
  use Ecto.Migration

  def change do
    create table(:partners) do
      add :server_service_id, references(:services, on_delete: :delete_all)
      add :client_service_id, references(:services, on_delete: :delete_all)
      add :active, :boolean

      timestamps
    end
  end
end
