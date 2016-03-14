use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :paladin, Paladin.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :comeonin, bcrypt_log_rounds: 1

config :guardian, Guardian,
  secret_key: "test",
  serializer: TestSupport.GuardianSerializer,
  permissions: %{
    paladin: [:write_connections, :read_connections],
    web: [:approve, :read, :write],
    addresses: [:wot, :now, :brown, :cow],
  }

config :paladin, Paladin.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "paladin_test",
  hostname: "localhost",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

config :paladin, Plug.Session,
  signing_salt: "test"
