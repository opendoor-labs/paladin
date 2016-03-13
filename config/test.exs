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
  secret_key: "development",
  permissions: %{
    paladin: [:write_connections, :read_connections],
    web: [:approve, :read, :write],
    addresses: [:wot, :now, :brown, :cow],
  }
