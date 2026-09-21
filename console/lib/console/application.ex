defmodule Console.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ConsoleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:console, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Console.PubSub},
      Console.Jobs,
      Console.Terminals,
      Console.Logs,
      Console.Events,
      Console.Resident,
      Console.Bench,
      # Start a worker by calling: Console.Worker.start_link(arg)
      # {Console.Worker, arg},
      # Start to serve requests, typically the last entry
      ConsoleWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Console.Supervisor]
    Supervisor.start_link(children ++ reports(), opts)
  end

  # The project's pages on a port of their own (ConsoleWeb.Reports);
  # none where it is not configured, as in the tests.
  defp reports do
    case Application.get_env(:console, :reports) do
      nil -> []
      opts -> [{Bandit, [plug: ConsoleWeb.Reports, scheme: :http] ++ opts}]
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ConsoleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
