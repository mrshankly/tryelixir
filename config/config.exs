# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the router
config :phoenix, Tryelixir.Router,
  url: [host: "localhost"],
  http: [port: System.get_env("PORT")],
  https: false,
  secret_key_base: "ApyeASmKu6XpDY1B2J0Br6tWWGQZIpmIUiEphdvn2IWfZv9s0UiSCNd0dR2L/I3pM8BdEkxWVNA6Pj68H3464w==",
  catch_errors: true,
  debug_errors: false,
  error_controller: Tryelixir.PageController

# Session configuration
config :phoenix, Tryelixir.Router,
  session: [store: :cookie,
            key: "_tryelixir_key"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
