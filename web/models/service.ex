defmodule Paladin.Service do
  use Paladin.Web, :model

  schema "services" do
    field :name, :string
    field :short_name, :string
    field :uuid, :string
    field :environment, :string
    field :secret, :string

    has_many :server_partners, Paladin.Partner, foreign_key: :server_service_id
    has_many :client_partners, Paladin.Partner, foreign_key: :client_service_id

    has_many :server_services, through: [:client_partners, :server_service]
    has_many :client_services, through: [:server_partners, :client_service]

    timestamps
  end

  @required_register_fields ~w(name short_name environment)a
  @optional_update_fields ~w(name short_name secret)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def register_changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_register_fields ++ ~w(secret)a)
    |> validate_required(@required_register_fields)
    |> set_uuid
    |> maybe_set_secret
    |> common_validations
  end

  def update_changeset(model, params \\ %{}) do
    model
    |> cast(params, @optional_update_fields)
    |> common_validations
  end

  def reset_secret_changeset(model) do
    model
    |> cast(%{}, [])
    |> put_change(:secret, generate_secret)
  end

  defp set_uuid(changeset) do
    put_change(changeset, :uuid, UUID.uuid4)
  end

  defp maybe_set_secret(changeset) do
    case fetch_field(changeset, :secret) do
      {_kind, val} when is_nil(val) ->
        put_change(changeset, :secret, generate_secret)
      :error ->
        put_change(changeset, :secret, generate_secret)
      _ -> changeset
    end
  end

  defp generate_secret do
    secret = UUID.uuid4 <> UUID.uuid4
    String.replace(secret, ~r/[-\s]/, "", global: true)
  end

  defp common_validations(changeset) do
    changeset
    |> validate_length(:secret, min: 8)
    |> validate_length(:name, min: 1)
    |> validate_length(:short_name, min: 1)
    |> validate_format(:short_name, ~r/^[^\s]+$/)
    |> validate_length(:environment, min: 3)
    |> validate_format(:environment, ~r/^[^\s]+$/)
    |> unique_constraint(:name_environment)
  end
end
