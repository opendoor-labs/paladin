defmodule Paladin.ViewHelpers do
  def logged_in?(conn), do: Guardian.Plug.authenticated?(conn)
  def user_display_name(conn) do
    {:ok, claims} = Guardian.Plug.claims(conn)
    claims["display_name"]
  end
end
