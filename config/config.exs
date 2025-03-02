# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configuration for Auth0 JWKs
config :auth0_jwks, json_library: Jason

# Enabling ANSI color codes for TTY emulation
config :elixir, ansi_enabled: true

config :lorem_ipsum,
  ecto_repos: [LoremIpsum.Repo]

# Configure your database
config :lorem_ipsum, LoremIpsum.Repo,
  migration_primary_key: [type: :uuid],
  migration_timestamps: [type: :naive_datetime_usec],
  generators: [timestamp_type: :utc_datetime_usec]

# Configures the endpoint
config :lorem_ipsum, LoremIpsumWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LoremIpsumWeb.ErrorHTML, json: LoremIpsumWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LoremIpsum.PubSub,
  live_view: [signing_salt: "cSOgYp0C"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :lorem_ipsum, LoremIpsum.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  lorem_ipsum: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  lorem_ipsum: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
