defmodule Paladin.LoginController do
  use Paladin.Web, :controller

  plug Ueberauth

  @spec request(Plug.Conn.t, map) :: Plug.Conn.t
  def request(conn, _params) do
    conn
    |> render(login_view_mod, "request.html")
  end

  @spec callback(Plug.Conn.t, map) :: Plug.Conn.t
  def callback(%Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case user_login_mod.find_and_verify_user(auth) do
      {:ok, user} ->
        login_mod = user_login_mod
        perms = login_mod.user_paladin_permissions(user)
        name = login_mod.user_display_name(user)

        conn
        |> Guardian.Plug.sign_in(user, :token, %{perms: perms, display_name: name})
        |> put_flash(:info, "Logged in #{user.full_name}")
        |> redirect(to: service_path(conn, :index))
      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: login_path(conn, :request, :identity))
    end
  end

  def callback(%Plug.Conn{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Could not authenticate")
    |> redirect(to: login_path(conn, :request, :identity))
  end

  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, _) do
    conn
    |> Guardian.Plug.sign_out
    |> redirect(to: service_path(conn, :index))
  end

  @spec login_view_mod :: Module.t
  defp login_view_mod do
    Application.get_env(:paladin, __MODULE__)[:view_module]
  end

  @spec login_view_mod :: Module.t
  defp user_login_mod do
    Application.get_env(:paladin, Paladin.UserLogin)[:module]
  end
end
