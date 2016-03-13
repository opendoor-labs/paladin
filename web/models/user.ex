defmodule Paladin.User do
  use Paladin.Web, :model

  schema "humans" do
    field :email, :string
    field :full_name, :string
    field :encrypted_password, :string
  end

  def find_by_email(email, repo) do
    if String.ends_with?(email, "@opendoor.com") do
      repo.get_by(__MODULE__, email: email)
    else
      nil
    end
  end

  def valid_password?(_, nil), do: false
  def valid_password?(%__MODULE__{} = user, password) do
    Comeonin.Bcrypt.checkpw(password, user.encrypted_password)
  end

  def login_changeset do
    cast(%__MODULE__{}, :empty, ~w(email password), [])
  end
end
