# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :paladin, Paladin.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Paladin.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :paladin, Paladin,
  default_ttl: 10 * 60

config :guardian, Guardian,
  issuer: "Paladin",
  allowed_algos: ["HS512", "HS256"],
  verify_issuer: false,
  permissions: %{
    paladin: [:write_connections, :read_connections],
  },
  serializer: PhoenixGuardian.GuardianSerializer

config :ueberauth, Ueberauth,
  providers: [
    identity: { Ueberauth.Strategy.Identity, [callback_methods: ["POST"]] }
  ]

config :comeonin, :bcrypt_log_rounds, 10

config :paladin, Paladin.LoginController,
  view_module: Paladin.LoginView

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :paladin, ecto_repos: []
