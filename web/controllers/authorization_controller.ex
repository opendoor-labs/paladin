defmodule Paladin.AuthorizationController do
  use Paladin.Web, :controller

  alias Paladin.Repo
  alias Paladin.AssertionAuth

  @doc """
  Receives assertion requests from partner services and re-encodes the
  assertion into a token that may be used by the server
  """
  def create(
    conn,
    %{
      "grant_type" => "urn:ietf:params:oauth:grant-type:sam12-bearer",
      "assertion" => assertion_jwt,
      "client_id" => client_id
    }
  ) do
    conn = put_resp_content_type(conn, "application/json")

    case AssertionAuth.assert_and_generate(client_id, assertion_jwt, Repo) do
      {:ok, response_jwt, full_claims} ->
        conn
        |> put_resp_header("x-expiry", to_string(full_claims["exp"]))
        |> render("create.json", jwt: response_jwt)

      {:error, reason} when reason in [:not_found, :aud_not_found] ->
        conn
        |> put_status(404)
        |> render("error.json", reason: reason)

      {:error, reason} ->
        conn
        |> put_status(401)
        |> render("error.json", reason: reason)

      _ ->
        conn
        |> put_status(500)
        |> render("error.json", reason: "unknown error")
    end
  end

  def create(conn, _) do
    conn
    |> put_status(400)
    |> render("error.json", reason: :bad_request)
  end
end
