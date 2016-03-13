defmodule Paladin.GuardianSerializer do
  @behaviour Guardian.Serializer

  alias Paladin.UserRepo
  alias Paladin.User

  def for_token(user) when is_binary(user), do: {:ok, user}
  def for_token(%User{} = user), do: {:ok, "User:#{user.id}"}
  def for_token(_), do: {:error, "Unknown resource type"}

  def from_token("User:" <> id) do
    case UserRepo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
  def from_token(val), do: {:ok, val}
end
