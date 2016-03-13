defmodule Paladin.AuthorizationView do
  use Paladin.Web, :view

  def render("create.json", %{jwt: jwt}) do
    %{token: jwt}
  end

  def render("error.json", %{reason: reason}) do
    %{
      error: reason,
      error_description: Phoenix.Naming.humanize(reason),
    }
  end
end
