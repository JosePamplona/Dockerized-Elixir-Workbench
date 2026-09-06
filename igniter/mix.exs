defmodule WorkbenchIgniter.MixProject do
  use Mix.Project

  def project do
    [
      app: :workbench_igniter,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: false,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:igniter, "~> 0.8"},
      # The --json output of workbench.catalog and workbench.status.
      {:jason, "~> 1.4"},
      # Used by workbench.install.exdoc to download the coding guidelines.
      {:req, "~> 0.5"},
      # Required by Igniter.Test.phx_test_project/1 to simulate
      # a Phoenix project in memory.
      {:phx_new, "~> 1.8", only: :test},
      # Static checks, run by CI: style and consistency, then success typing.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
