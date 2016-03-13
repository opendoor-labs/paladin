defmodule Paladin.ServerPartnerView do
  use Paladin.Web, :view

  def available_permissions do
    Guardian.Permissions.all_available
    |> Map.drop([:paladin])
    |> Enum.into([])
    |> Enum.sort(&(elem(&1, 0) < elem(&2, 0)))
  end

  def has_permission?(service, group, permission) do
    service_has_permission?(
      service.permissions[to_string(group)],
      permission,
      group
    )
  end

  defp service_has_permission?(nil, _, _group), do: false
  defp service_has_permission?(-1, -1, _group), do: true
  defp service_has_permission?(v, perm, group), do: Guardian.Permissions.all?(v, List.wrap(perm), group)
end
