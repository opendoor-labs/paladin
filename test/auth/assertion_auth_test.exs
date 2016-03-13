defmodule Paladin.AssertionAuthTest do
  use Paladin.ModelCase

  alias Paladin.Service
  alias Paladin.Partner
  alias Paladin.AssertionAuth, as: Auth
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

  setup do
    service1 = Service.register_changeset(%Service{}, @s1_attrs) |> Repo.insert!
    service2 = Service.register_changeset(%Service{}, @s2_attrs) |> Repo.insert!

    partner = Partner.changeset(
      build_assoc(service1, :client_partners),
      %{
        server_service_id: service2.id,
        permissions: %{
          "web" => 6, # read/write
          "addresses" => 1 # wot
        },
        ttl_seconds: 3600
      }
    )
    |> Repo.insert!

    c = %{
      headers: %{aud: service2.uuid},
      secret: service1.secret,
      aud: service2.uuid,
      sub: service2.short_name,
      some: "thing",
      rexp: Guardian.Utils.timestamp + 5 * 24 * 60 * 60,
      perms: %{
        "web" => -1,
        "addresses" => -1
      }
    }

    {:ok, jwt, claims} = Guardian.encode_and_sign(service2.uuid, :token, c)

    {
      :ok,
      s1: service1,
      s2: service2,
      partnership: partner,
      jwt: jwt,
      claims: claims
    }
  end

  test "can only decode the jwt with service 1 secret", %{s1: s1, s2: s2, jwt: jwt} do
    {:error, reason} = Guardian.decode_and_verify(jwt)
    assert reason == :invalid_token

    {:error, reason} = Guardian.decode_and_verify(jwt, %{secret: s2.secret})
    assert reason == :invalid_token

    {:ok, claims} = Guardian.decode_and_verify(jwt, %{secret: s1.secret})
    assert claims["aud"] == s2.uuid
  end

  test "does not decode when the client id is not the generator", %{s2: s2, jwt: jwt} do
    {:error, :invalid_token} = Auth.assert_and_generate(s2.uuid, jwt, Repo)
  end

  test "provides a token signed by the aud secret", %{s1: s1, s2: s2, jwt: jwt, claims: claims, partnership: p} do
    {:ok, s2_jwt, new_claims} = Auth.assert_and_generate(s1.uuid, jwt, Repo)

    {:ok, _claims} = Guardian.decode_and_verify(s2_jwt, %{secret: s2.secret})

    refute new_claims["jti"] == claims["jti"]
    assert new_claims["sub"] == claims["sub"]
    assert new_claims["aud"] == s2.uuid
    assert new_claims["some"] == "thing"
    assert new_claims["exp"] == new_claims["iat"] + p.ttl_seconds
  end

  test "encodes the aud in the header of the token", %{s1: s1, s2: s2, jwt: jwt} do
    {:ok, s2_jwt, _new_claims} = Auth.assert_and_generate(s1.uuid, jwt, Repo)

    headers = Guardian.peek_header(s2_jwt)
    assert headers["aud"] == s2.uuid
  end

  test "bails if the services aren't configured to talk", %{s1: s1, jwt: jwt, partnership: p} do
    Repo.delete!(p)

    {:error, reason} = Auth.assert_and_generate(s1.uuid, jwt, Repo)
    assert reason == :unauthorized
  end

  test "bails if it cannot find the service", %{s1: s1, s2: s2, jwt: jwt} do
    Repo.delete!(s2)

    {:error, reason} = Auth.assert_and_generate(s1.uuid, jwt, Repo)
    assert reason == :aud_not_found
  end

  test "maxes out on the granted permissions", %{s1: s1, jwt: jwt} do
    {:ok, _s2_jwt, new_claims} = Auth.assert_and_generate(s1.uuid, jwt, Repo)

    assert new_claims["pem"]["web"] == 6
    assert new_claims["pem"]["addresses"] == 1
  end

  test "maxes out the ttl", %{s1: s1, jwt: jwt, partnership: p}  do
    {:ok, _s2_jwt, new_claims} = Auth.assert_and_generate(s1.uuid, jwt, Repo)

    expected_exp = new_claims["iat"] + p.ttl_seconds

    assert new_claims["exp"] == expected_exp
  end
end
