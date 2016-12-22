defmodule Paladin.AssertionAuth do
  @moduledoc """
  Handles assertion authorization code requests
  Services must be configured via a partnership
  The service playing the role of client may assert via this mechanism to talk
  to the configured server service.

  Important things to note:

  In your assertion token:

  * sub - This should be who the token is on behalf. If just the server use "anon"
  * aud - Must be the server services uuid that you want to talk to
  * You may add any other things that you want to the token and they will be propagated through
  * Tokens are granted for 10 minutes life
  """

  require Bitwise

  import Ecto.Query, only: [from: 1, from: 2]
  alias Paladin.Service
  alias Paladin.Partner

  def assert_and_generate(id, _, _) when length(id) == 0 or is_nil(id) do
    {:error, :client_id_required}
  end

  def assert_and_generate(_, jwt, _) when length(jwt) == 0 or is_nil(jwt) do
    {:error, :client_assertion_required}
  end

  @doc """
  Validate the assertion token provided by the client mapped to client_uuid
  make sure that the server requested in the aud has the correct partnership setup
  """
  def assert_and_generate(client_uuid, jwt, repo) do
    assert_service(repo.get_by(Service, uuid: client_uuid), jwt, repo)
  end

  defp assert_service(nil, _, _repo), do: {:error, :not_found}

  defp assert_service(%Service{} = client_service, jwt, repo) do
    case Guardian.decode_and_verify(jwt, %{secret: client_service.secret}) do
      {:ok, claims} ->
        if server_service = repo.get_by(Service, uuid: claims["aud"]) do
          partnership = partnership(server_service, client_service, repo)
          if partnership do
            generate_token(claims, server_service, partnership)
          else
            {:error, :unauthorized}
          end
        else
          {:error, :aud_not_found}
        end
      error -> error
    end
  end

  defp generate_token(claims, service, partnership) do
    default_claims = Guardian.Claims.app_claims
      |> Guardian.Claims.jti
      |> Guardian.Claims.iat
      |> Guardian.Claims.nbf
      |> Map.put(:secret, service.secret)
      |> Map.put(:headers, %{aud: service.uuid})
      |> filter_max_permissions(claims, partnership)
      |> maximum_ttl(claims, partnership)

    claims = Map.drop(claims, ~w(perms pem ttl rexp exp))
    merged_claims = Map.merge(claims, default_claims)

    Guardian.encode_and_sign(
      claims["sub"],
      claims["typ"] || :access,
      merged_claims
    )
  end

  defp partnership(%Service{id: server_id}, %Service{id: client_id}, repo) do
    query = from p in Partner,
            where: p.server_service_id == ^server_id,
            where: p.client_service_id == ^client_id,
            limit: 1

    result = repo.all(query)
    if length(result) > 0 do
      hd(result)
    else
      nil
    end
  end

  # We have requested permissions as a map of key to bitma and
  # map of max permissions on the partnership
  # This function ensures that the requested permissions never exceed
  # the requested permissions
  defp filter_max_permissions(new_claims, claims, partnership) do
    requested = claims["pem"] || %{}
    max = partnership.permissions || %{}

    pem_keys = requested
    |> Map.keys
    |> MapSet.new

    max_pem_keys = max
    |> Map.keys
    |> MapSet.new

    extra = MapSet.difference(pem_keys, max_pem_keys)
    |> Enum.into([])

    # Drop any that aren't even in the list of allowed permissions
    requested = Map.drop(requested, extra)

    new_permissions = requested
    |> Enum.map(fn {key, value} ->
      max_value = Bitwise.band(max[key], value)
      if max_value == 0 do
        nil
      else
        {key, max_value}
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.into(%{})

    new_claims
    |> Map.drop(["perms", "pem"])
    |> Map.put("perms", new_permissions)
  end

  defp maximum_ttl(new_claims, %{"rexp" => requested_ttl} = claims, partnership) do
    current_request = requested_ttl - new_claims["iat"]
    if partnership.ttl_seconds > current_request do
      Map.put(new_claims, "ttl", {current_request, :seconds})
    else
      Map.put(new_claims, "ttl", {partnership.ttl_seconds, :seconds})
    end
  end

  defp maximum_ttl(new_claims, _claims, partnership) do
    Map.put(new_claims, "ttl", {partnership.ttl_seconds, :seconds})
  end
end
