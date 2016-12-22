defmodule Paladin.ServiceTest do
  use Paladin.ModelCase

  alias Paladin.Service

  @valid_attrs %{environment: "production", name: "Some App", short_name: "some_app"}
  @invalid_attrs %{}

  test "registration with valid attributes" do
    changeset = Service.register_changeset(%Service{}, @valid_attrs)
    assert changeset.valid?
    refute get_change(changeset, :secret) == nil
    refute get_change(changeset, :uuid) == nil
  end

  test "registration invalid when short name has a space" do
    attrs = %{@valid_attrs | short_name: "some thing"}
    changeset = Service.register_changeset(%Service{}, attrs)
    refute changeset.valid?
    refute Keyword.get(changeset.errors, :short_name) == nil
  end

  test "registration when secret is too short" do
    attrs = Map.put(@valid_attrs, :secret, "asdfasd")
    changeset = Service.register_changeset(%Service{}, attrs)
    refute changeset.valid?
    refute Keyword.get(changeset.errors, :secret) == nil
  end

  test "registration when secret is ok" do
    attrs = Map.put(@valid_attrs, :secret, "asdfasdf")
    changeset = Service.register_changeset(%Service{}, attrs)
    assert changeset.valid?
    assert changeset.changes[:secret] == "asdfasdf"
  end

  test "registration when name is too short" do
    attrs = %{@valid_attrs | name: ""}
    changeset = Service.register_changeset(%Service{}, attrs)
    refute changeset.valid?
    refute Keyword.get(changeset.errors, :name) == nil
  end

  test "registration when environment is too short" do
    attrs = %{@valid_attrs | environment: "a"}
    changeset = Service.register_changeset(%Service{}, attrs)
    refute changeset.valid?
    refute Keyword.get(changeset.errors, :environment) == nil
  end

  test "registration when environment contains a space" do
    attrs = %{@valid_attrs | environment: "abc bca"}
    changeset = Service.register_changeset(%Service{}, attrs)
    refute changeset.valid?
    refute Keyword.get(changeset.errors, :environment) == nil
  end

  test "registration sets a uuid" do
    changeset = Service.register_changeset(%Service{}, @valid_attrs)
    assert changeset.valid?
    refute changeset.changes[:uuid] == nil
  end

  test "does not set a uuid from params" do
    attrs = Map.put(@valid_attrs, :uuid, "ABCDEF")
    changeset = Service.register_changeset(%Service{}, attrs)
    assert changeset.valid?
    refute changeset.changes[:uuid] == "ABCDEF"
  end

  test "updating lets me change the name short name secret and environment" do
    {:ok, service} = Repo.insert(Service.register_changeset(%Service{}, @valid_attrs))
    update_attrs = %{
      name: "foo",
      short_name: "bar",
      environment: "staging",
      secret: "ABCDEFGH",
      uuid: "blahblahblah"
    }
    {:ok, updated_service} = Service.update_changeset(service, update_attrs) |> Repo.update

    assert updated_service.name == "foo"
    assert updated_service.short_name == "bar"
    assert updated_service.secret == "ABCDEFGH"
    assert updated_service.uuid == service.uuid
  end

  test "updating with the same name and environemnt" do
    {:ok, _service} = Service.register_changeset(%Service{}, @valid_attrs) |> Repo.insert
    {:error, cs} = Service.register_changeset(%Service{}, @valid_attrs) |> Repo.insert
    assert Keyword.get(cs.errors, :name_environment) == {"has already been taken", []}
  end
end
