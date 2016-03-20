use Mix.Config

# Configure your database
config :paladin, Paladin.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "paladin_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :devise_user, DeviseUser.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "web_development",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
