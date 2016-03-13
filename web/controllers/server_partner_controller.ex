defmodule Paladin.ServerPartnerController do
  @moduledoc """
  Maps servers a service can talk to
  """
  use Paladin.Web, :controller

  alias Paladin.Service
  alias Paladin.Partner

  plug :scrub_params, "partner" when action in [:create, :update]

  def new(conn, _params, service) do
    services = other_services(service) |> Repo.all
    changeset = Partner.changeset(%Partner{})
    render(
      conn,
      "new.html",
      changeset: changeset,
      service: service,
      services: services,
      server_partner: %Partner{}
    )
  end

  def create(conn, %{"partner" => server_partner_params}, service) do
    changeset = service
      |> build_assoc(:client_partners)
      |> Partner.changeset(server_partner_params)
      |> Ecto.Changeset.put_change(
        :permissions,
        permissions_from_params(server_partner_params["permissions"])
      )

    case Repo.insert(changeset) do
      {:ok, _server_partner} ->
        conn
        |> put_flash(:info, "Server partner created successfully.")
        |> redirect(to: service_path(conn, :show, service))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, service: service)
    end
  end

  def show(conn, %{"id" => id}, service) do
    server_partner = service
      |> assoc(:client_partners)
      |> Repo.get!(id)
    render(conn, "show.html", server_partner: server_partner, service: service)
  end

  def edit(conn, %{"id" => id}, service) do
    server_partner = Repo.one!(from p in Partner, where: p.id == ^id, preload: [:server_service, :client_service])
    changeset = Partner.changeset(server_partner)
    render(
      conn,
      "edit.html",
      server_partner: server_partner,
      changeset: changeset,
      service: service,
      services: []
    )
  end

  def update(conn, %{"id" => id, "partner" => server_partner_params}, service) do
    server_partner = Repo.get!(Partner, id)
    changeset = Partner.changeset(server_partner, server_partner_params)
    |> Ecto.Changeset.put_change(
      :permissions,
      permissions_from_params(server_partner_params["permissions"])
    )

    case Repo.update(changeset) do
      {:ok, server_partner} ->
        conn
        |> put_flash(:info, "Server partner updated successfully.")
        |> redirect(to: service_server_partner_path(conn, :show, service, server_partner))
      {:error, changeset} ->
        render(conn, "edit.html", server_partner: server_partner, changeset: changeset, service: service)
    end
  end

  def delete(conn, %{"id" => id}, service) do
    server_partner = Repo.get!(Partner, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(server_partner)

    conn
    |> put_flash(:info, "Server partner deleted successfully.")
    |> redirect(to: service_path(conn, :show, service))
  end

  def action(conn, _) do
    service = Repo.get!(Service, conn.params["service_id"])
    apply(
      __MODULE__,
      action_name(conn),
      [conn, conn.params, service]
    )
  end

  defp other_services(service) do
    others = all_other_services(service)
    service_id = service.id

    existing_services = (from p in Partner,
      where: p.client_service_id == ^service_id,
      select: p.server_service_id)
    |> Repo.all

    others
    |> Ecto.Query.where([o], o.id != ^service_id)
    |> Ecto.Query.where([o], not o.id in ^existing_services)
  end

  defp all_other_services(%Service{id: id}) do
    from s in Service, where: s.id != ^id
  end

  defp permissions_from_params(nil), do: %{}
  defp permissions_from_params(params) do
    mapped_perms = for {group, vals} <- params, do: permission_values(group, vals)
    mapped_perms
    |> Enum.filter(&(&1 != nil))
    |> Enum.into(%{})
  end

  defp permission_values("paladin", _), do: nil
  defp permission_values(group, values) do
    if Enum.member?(values, "max") do
      {group, -1}
    else
      val = Guardian.Permissions.to_value(List.wrap(values), group)
      if val == 0 do
        nil
      else
        {group, val}
      end
    end
  end
end
