use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :paladin, Paladin.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "LOxSDHroTDkAd5cesDkdE38zjsUqhoogGZigOENvDvvw0yYdOrDY5BLO3paWCTFT",
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]]

# Watch static and templates for browser reloading.
config :paladin, Paladin.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20

config :guardian, Guardian,
  secret_key: "development"

config :paladin, Paladin.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "paladin_dev",
  hostname: "localhost",
  pool_size: 10

config :paladin, Plug.Session,
  signing_salt: "development"
