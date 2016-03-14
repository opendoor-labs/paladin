defmodule Paladin.AuthErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  import Plug.Conn
  import Paladin.Router.Helpers
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  def unauthenticated(conn, _) do
    case Phoenix.Controller.get_format(conn) do
      "json" ->
        send_resp(conn, 401, Poison.encode!(%{error: true, message: "Unauthenticated"}))
      _ ->
        conn
        |> put_flash(:error, "Authenitcation required")
        |> redirect(to: login_path(conn, :request, :identity))
    end
  end

  def unauthorized(conn, _) do
    case Phoenix.Controller.get_format(conn) do
      "json" ->
        send_resp(conn, 403, Poison.encode!(%{error: true, message: "Unauthorized"}))
      _ ->
        conn
        |> put_flash(:error, "You are not authorized to see this resource")
        |> redirect(to: login_path(conn, :request, :identity))
    end
  end
end
