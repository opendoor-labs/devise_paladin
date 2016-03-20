defmodule DeviseUser.User do
  use Ecto.Schema
  import Ecto
  import Ecto.Changeset
  import Ecto.Query, only: [from: 1, from: 2]

  @type email :: String.t
  @type t :: %__MODULE__{
    id: Integer.t,
    email: email,
    encrypted_password: String.t
  }

  schema "users" do
    field :email, :string
    field :encrypted_password, :string
  end
end
