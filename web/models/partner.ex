defmodule Paladin.Partner do
  use Paladin.Web, :model

  schema "partners" do
    belongs_to :server_service, Paladin.Service
    belongs_to :client_service, Paladin.Service

    field :permissions, :map, default: %{}
    field :ttl_seconds, :integer, default: 10 * 60

    timestamps
  end

  @required_fields ~w(server_service_id client_service_id)a
  @optional_fields ~w(permissions ttl_seconds)a
  @all_fields @required_fields ++ @optional_fields

  @goc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
  end
end
