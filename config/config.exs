# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :wwed,
  ecto_repos: [Wwed.Repo]

# Configures the endpoint
config :wwed, WwedWeb.Endpoint,
  url: [host: "wwed.gigalixir.com"],
  secret_key_base: "OYrKzw9cbNnIDw5z+eP6C99D438yxqrWOjYPDQ8EIH621ZT1bFZS0QgdHaLp86nN",
  render_errors: [view: WwedWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Wwed.PubSub,
  live_view: [signing_salt: "27oGetyl"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
