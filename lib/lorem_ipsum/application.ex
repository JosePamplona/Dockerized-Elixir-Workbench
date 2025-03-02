defmodule LoremIpsum.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LoremIpsumWeb.Telemetry,
      LoremIpsum.Repo,
      {DNSCluster, query: Application.get_env(:lorem_ipsum, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LoremIpsum.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LoremIpsum.Finch},
      # Start a worker by calling: LoremIpsum.Worker.start_link(arg)
      # {LoremIpsum.Worker, arg},
      # Start to serve requests, typically the last entry
      LoremIpsumWeb.Endpoint,
      # Start the process to request the JSON Web Key Set (with RS256 alg).
      {Auth0Jwks.Strategy, first_fetch_sync: true}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LoremIpsum.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LoremIpsumWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
