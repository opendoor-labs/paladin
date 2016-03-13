defmodule Paladin.AuthorizationControllerTest do
  use Paladin.ConnCase

  alias Paladin.Service
  alias Paladin.Partner
  alias Paladin.Repo

  @s1_attrs %{
    environment: "production",
    name: "one",
    short_name: "one",
    secret: "secretsecret1"
  }

  @s2_attrs %{
    environment: "production",
    name: "two",
    short_name: "two",
    secret: "secretsecret2"
  }

  @valid_grant "urn:ietf:params:oauth:grant-type:sam12-bearer"

  setup %{conn: conn} do
    service1 = Service.register_changeset(%Service{}, @s1_attrs) |> Repo.insert!
    service2 = Service.register_changeset(%Service{}, @s2_attrs) |> Repo.insert!

    partner = Partner.changeset(
      build_assoc(service1, :client_partners),
      %{server_service_id: service2.id}
    )
    |> Repo.insert!

    c = %{
      headers: %{aud: service2.uuid},
      secret: service1.secret,
      aud: service2.uuid,
      sub: service2.short_name,
      some: "thing"
    }

    {:ok, jwt, claims} = Guardian.encode_and_sign(service2.uuid, :token, c)

    {
      :ok,
      conn: conn,
      s1: service1,
      s2: service2,
      partnership: partner,
      jwt: jwt,
      claims: claims
    }
  end

  test "POST /authorize", %{conn: conn} do
    conn = post conn, "/authorize"
    body = json_response(conn, 400)
    assert "bad_request" == body["error"]
    assert "Bad request" == body["error_description"]
  end

  test "POST /authorize with a bad grant type", %{conn: conn, jwt: jwt, s1: s1} do
    conn = post conn, "/authorize", grant_type: "badgrant", assertion: jwt, client_id: s1.uuid

    body = json_response(conn, 400)
    assert "bad_request" == body["error"]
    assert "Bad request" == body["error_description"]
  end

  test "POST /authorize with no client_id", %{conn: conn, jwt: jwt} do
    conn = post conn, "/authorize", grant_type: @valid_grant, assertion: jwt

    body = json_response(conn, 400)
    assert "bad_request" == body["error"]
    assert "Bad request" == body["error_description"]
  end

  test "POST /authorize with no assertion", %{conn: conn, s1: s1} do
    conn = post conn, "/authorize", grant_type: @valid_grant, client_id: s1.uuid

    body = json_response(conn, 400)
    assert "bad_request" == body["error"]
    assert "Bad request" == body["error_description"]
  end

  test "POST /authorize with a dodgy client", %{conn: conn, jwt: jwt} do
    conn = post conn, "/authorize", grant_type: @valid_grant, client_id: "BAD", assertion: jwt

    body = json_response(conn, 404)
    assert "not_found" == body["error"]
    assert "Not found" == body["error_description"]
  end

  test "POST /authorize with a bad token", %{conn: conn, s2: s2, jwt: jwt} do
    conn = post conn, "/authorize", grant_type: @valid_grant, client_id: s2.uuid, assertion: jwt

    body = json_response(conn, 401)
    assert "invalid_token" == body["error"]
    assert "Invalid token" == body["error_description"]
  end

  test "POST /authorize for an unknown audience", %{conn: conn, s1: s1, s2: s2, jwt: jwt} do
    Repo.delete!(s2)
    conn = post conn, "/authorize", grant_type: @valid_grant, client_id: s1.uuid, assertion: jwt

    body = json_response(conn, 404)
    assert "aud_not_found" == body["error"]
    assert "Aud not found" == body["error_description"]
  end

  test "POST /authorize for a good request", %{conn: conn, s1: s1, s2: s2, jwt: jwt} do
    conn = post conn, "/authorize", grant_type: @valid_grant, client_id: s1.uuid, assertion: jwt

    body = json_response(conn, 200)

    {:ok, claims} = Guardian.decode_and_verify(body["token"], %{secret: s2.secret})

    exp_header = get_resp_header(conn, "x-expiry") |> hd

    assert exp_header == to_string(claims["exp"])
  end
end
