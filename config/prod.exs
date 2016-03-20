use Mix.Config

config :paladin, Paladin.Endpoint,
  url: [scheme: "https", host: System.get_env("HOST"), port: 433]

config :devise_user, DeviseUser.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("USER_DATABASE_URL"),
  pool_size: 10

config :paladin, Plug.Session,
  signing_salt: "oiwuierojSEjre3"

