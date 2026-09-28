import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/console start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :console, ConsoleWeb.Endpoint, server: true
end

config :console, ConsoleWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :console, ConsoleWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/console_web/router\.ex$",
        ~r"lib/console_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  # The release, as './wb.sh console' runs it: on 0.0.0.0 inside the
  # container, published on 127.0.0.1 by Docker, on the first free port
  # from 4100 — CONSOLE_PUBLIC_PORT, the port the browser sees while the
  # container listens on PORT. The secret is made by wb.sh at each start
  # and kept nowhere: a console is one session, and its cookies with it.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  public_port = System.get_env("CONSOLE_PUBLIC_PORT") || System.get_env("PORT") || "4000"

  config :console, ConsoleWeb.Endpoint,
    url: [host: "localhost", port: String.to_integer(public_port), scheme: "http"],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
    # The console runs wb.sh with --yes over Docker's socket, and
    # `delete` wipes a workspace: no page the reader visits while the
    # console is up may open its socket. The port is part of the check —
    # the project's pages are served on the port beside this one, the
    # same host, and "//localhost" alone would let them in.
    check_origin: ["//localhost:#{public_port}", "//127.0.0.1:#{public_port}"],
    secret_key_base: secret_key_base

  # The project's docs and coverage report, on their own origin
  # (ConsoleWeb.Reports): the port beside the console's, published on
  # 127.0.0.1 like it.
  config :console, :reports,
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("REPORTS_PORT") || "4001")
end
