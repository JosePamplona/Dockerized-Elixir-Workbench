defmodule Console.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    scrub_release_env()

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

  # The release's own runtime, out of the environment every process the
  # console starts inherits — a job's wb.sh, the resident's mix, git,
  # docker. ERTS puts its bin directory first on PATH and exports where
  # it lives (ROOTDIR, BINDIR, EMU, PROGNAME), and the release script
  # its RELEASE_* — so a `mix` spawned from here found the release's
  # `erl`, whose root has no start.boot, and died booting ("cannot get
  # bootfile", 2026-09-28). Under mix (`console dev`) RELEASE_ROOT is
  # unset and nothing is touched. The VM itself reads none of these
  # after boot.
  defp scrub_release_env do
    case System.get_env("RELEASE_ROOT") do
      nil ->
        :ok

      root ->
        path =
          System.get_env("PATH", "")
          |> String.split(":")
          |> Enum.reject(&String.starts_with?(&1, root <> "/"))
          |> Enum.join(":")

        System.put_env("PATH", path)

        System.get_env()
        |> Map.keys()
        |> Enum.filter(
          &(&1 in ~w(ROOTDIR BINDIR EMU PROGNAME) or String.starts_with?(&1, "RELEASE_"))
        )
        |> Enum.each(&System.delete_env/1)
    end
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
