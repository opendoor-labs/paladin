defmodule Paladin.UserLogin do
  @doc """
  Find the user from the Ueuberauth.Auth struct passed in.
  """
  @callback find_and_verify_user(Ueberauth.Auth.t) :: {:ok, any} | {:error, atom}

  @doc """
  Provide the display name for a user from your serializer.
  """
  @callback user_display_name(any) :: String.t

  @doc """
  Given the user found from `find_and_verify_user`
  provide the permissions map that will be used in Paladins Guardian token.
  This is for people using the front end of Paladin rather than services.
  """
  @callback user_paladin_permissions(any) :: int | Map.t
end
