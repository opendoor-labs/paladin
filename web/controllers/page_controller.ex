defmodule Paladin.PageController do
  use Paladin.Web, :controller

  def index(conn, _params) do
    redirect(conn, to: service_path(conn, :index))
  end
end
