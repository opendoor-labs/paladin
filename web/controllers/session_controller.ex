defmodule Paladin.SessionController do
  use Paladin.Web, :controller

  alias Paladin.User
  alias Paladin.UserRepo

  plug :scrub_params, "user" when action in [:create]

  def new(conn, _) do
    changeset = User.login_changeset
    conn
    |> Guardian.Plug.sign_out(:default)
    |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.find_by_email(email, UserRepo) do
      nil ->
        conn
        |> put_flash(:error, "Invalid password or email")
        |> render("new.html", changeset: User.login_changeset)
      user ->
        if User.valid_password?(user, password) do
          conn
          |> Guardian.Plug.sign_in(user)
          |> put_flash(:info, "Logged in #{user.full_name}")
          |> redirect(to: service_path(conn, :index))
        else
          conn
          |> put_flash(:error, "Invalid password or email")
          |> render("new.html", changeset: User.login_changeset)
        end
    end
  end

  def delete(conn, _) do
    conn
    |> Guardian.Plug.sign_out
    |> redirect(to: login_path(conn, :new))
  end
end
