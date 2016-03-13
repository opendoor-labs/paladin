defmodule Paladin.Partner do
  use Paladin.Web, :model

  schema "partners" do
    belongs_to :server_service, Paladin.Service
    belongs_to :client_service, Paladin.Service

    field :permissions, :map, default: %{}
    field :ttl_seconds, :integer, default: 10 * 60

    timestamps
  end

  @required_fields ~w(server_service_id client_service_id)
  @optional_fields ~w(permissions ttl_seconds)

  @goc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
