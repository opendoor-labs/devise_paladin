use Mix.Config

# Configure your database
config :devise_user, DeviseUser.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("USER"),
  password: "",
  database: "web_development",
  hostname: "localhost",
  pool_size: 5

