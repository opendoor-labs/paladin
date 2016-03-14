defmodule TestSupport.GuardianSerializer do
  @behaviour Guardian.Serializer

  def for_token(user), do: {:ok, user}
  def from_token(val), do: {:ok, val}
end
