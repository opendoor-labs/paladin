defmodule Paladin.ServiceController do
  use Paladin.Web, :controller

  alias Guardian.Plug.EnsureAuthenticated

  plug EnsureAuthenticated, handler: Paladin.AuthErrorHandler

  alias Paladin.Service

  plug :scrub_params, "service" when action in [:create, :update]

  def index(conn, _params) do
    query = from s in Service, order_by: [:environment, :name]
    services = Repo.all(query)
    render(conn, "index.html", services: services)
  end

  def new(conn, _params) do
    changeset = Service.register_changeset(%Service{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"service" => service_params}) do
    changeset = Service.register_changeset(%Service{}, service_params)

    case Repo.insert(changeset) do
      {:ok, _service} ->
        conn
        |> put_flash(:info, "Service created successfully.")
        |> redirect(to: service_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    query = from s in Service,
                where: s.id == ^id,
                left_join: cp in assoc(s, :client_partners),
                left_join: ss in assoc(cp, :server_service),
                left_join: sp in assoc(s, :server_partners),
                left_join: cs in assoc(sp, :client_service),
                preload: [
                  client_partners: {cp, server_service: ss},
                  server_partners: {sp, client_service: cs}
                ]

    service = Repo.one(query)

    render(conn, "show.html", service: service)
  end

  def edit(conn, %{"id" => id}) do
    service = Repo.get!(Service, id)
    changeset = Service.update_changeset(service)
    render(conn, "edit.html", service: service, changeset: changeset)
  end

  def update(conn, %{"id" => id, "service" => service_params}) do
    service = Repo.get!(Service, id)
    changeset = Service.update_changeset(service, service_params)

    case Repo.update(changeset) do
      {:ok, service} ->
        conn
        |> put_flash(:info, "Service updated successfully.")
        |> redirect(to: service_path(conn, :show, service))
      {:error, changeset} ->
        render(conn, "edit.html", service: service, changeset: changeset)
    end
  end

  def reset_secret(conn, %{"service_id" => id}) do
    result = Service
    |> Repo.get!(id)
    |> Service.reset_secret_changeset
    |> Repo.update

    case result do
      {:ok, service} ->
        conn
        |> put_flash(:info, "Secret updated")
        |> redirect(to: service_path(conn, :show, id))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not update secret")
        |> redirect(to: service_path(conn, :show, id))
    end
  end

  def delete(conn, %{"id" => id}) do
    service = Repo.get!(Service, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(service)

    conn
    |> put_flash(:info, "Service deleted successfully.")
    |> redirect(to: service_path(conn, :index))
  end
end
