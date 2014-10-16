use Mix.Config

# ## SSL Support
#
# To get SSL working, you will need to set:
#
#     https: [port: 443,
#             keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#             certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables point to a file on
# disk for the key and cert.

config :phoenix, Tryelixir.Router,
  url: [host: "example.com"],
  http: [port: System.get_env("PORT")],
  secret_key_base: "ApyeASmKu6XpDY1B2J0Br6tWWGQZIpmIUiEphdvn2IWfZv9s0UiSCNd0dR2L/I3pM8BdEkxWVNA6Pj68H3464w=="

config :logger, :console,
  level: :info
