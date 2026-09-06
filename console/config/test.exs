import Config

# The bench reads nothing at boot in tests: a reading starts a container.
config :console, bench_reads_at_boot: false
# And the events feed listens to nothing: there is no daemon to hear.
config :console, events_at_boot: false
# And the Docker screen asks the daemon nothing.
config :console, docker_reads: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :console, ConsoleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "J8LpX2VX1NNCKsN3SmOn+av3/YOdVjUrZ9ojERVG10kd3NRWLzd9+9OqNGumyTAr",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
