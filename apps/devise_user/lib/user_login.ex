defmodule DeviseUser.UserLogin do
  alias DeviseUser.User
  alias DeviseUser.Repo

  @behaviour Paladin.UserLogin

  @spec find_and_verify_user(Ueberauth.Auth.t | nil) :: {:error, atom | String.t} | {:ok, any}
  def find_and_verify_user(nil), do: {:error, :not_found}

  def find_and_verify_user(%Ueberauth.Auth{}=auth) do
    email = auth.info.email
    if matches_configured_regex?(email) do
      case Repo.get_by(User, email: email) do
        nil -> {:error, :not_found}
        user ->
          password = auth.credentials.other.password
          if valid_password?(user, password) do
            {:ok, user}
          else
            {:error, :invalid_password}
          end
      end
    else
      {:error, :not_found}
    end
  end

  @spec user_paladin_permissions(User.t | any) :: map
  def user_paladin_permissions(%User{}) do
    %{
      paladin: Guardian.Permissions.max
    }
  end
  def user_paladin_permissions(_), do: %{}

  @spec user_display_name(nil | String.t | User.t) :: String.t
  def user_display_name(nil), do: "Anonymous"
  def user_display_name(name) when is_binary(name), do: name
  def user_display_name(%User{} = user), do: user.email

  @spec valid_password?(User.t | nil, String.t | nil) :: boolean
  defp valid_password?(_, nil), do: false
  defp valid_password?(user, password) do
    Comeonin.Bcrypt.checkpw(password, user.encrypted_password)
  end

  defp matches_configured_regex?(email) do
    reg_string = Application.get_env(:paladin, Paladin.UserLogin)[:authorized_email_regex]
    match_authorized_email?(email, reg_string)
  end

  defp match_authorized_email?(nil, _), do: false
  defp match_authorized_email?(email, nil), do: true

  defp match_authorized_email?(email, reg_string) do
    {:ok, reg} = Regex.compile(reg_string)
    email =~ reg
  end
end
