defmodule DeviseUser.GuardianSerializer do
  @behaviour Guardian.Serializer

  require DeviseUser.User

  alias DeviseUser.Repo
  alias DeviseUser.User

  @spec for_token(any) :: {:ok, String.t} | {:error, String.t | atom}
  def for_token(user) when is_binary(user), do: {:ok, user}
  def for_token(%User{} = user), do: {:ok, "User:#{user.id}"}
  def for_token(_), do: {:error, "Unknown resource type"}

  @spec from_token(String.t) :: {:ok, DeviseUser.User.t | String.t} | {:error, atom | String.t}
  def from_token("User:" <> id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
  def from_token(val), do: {:ok, val}
end
