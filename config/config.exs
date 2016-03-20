# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

config :paladin, Paladin.UserLogin,
  module: DeviseUser.UserLogin,
  authorized_email_regex: System.get_env("PALADIN_USER_EMAIL_REGEX")

config :guardian, Guardian,
  serializer: DeviseUser.GuardianSerializer

# Add your permissions for Guardian here.
# By default you should at least include the Paladin permissions (there by
# default)

#config :guardian, Guardian,
#  permissions: %{
#    paladin: [:write_connections, :read_connections],
#  }

import_config "#{Mix.env}.exs"
