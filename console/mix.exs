defmodule Console.MixProject do
  use Mix.Project

  def project do
    [
      app: :console,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Console.Application, []},
      # :inets and :ssl are what Console.Installers asks hex with — OTP's
      # own client, so the console carries no HTTP dependency for it.
      # :mix because the catalog is read in this BEAM off the package's
      # Mix tasks (Console.Catalog → Mix.Tasks.Workbench.Catalog, and
      # each box's summary is its task's @shortdoc, Mix.Task.shortdoc/1):
      # a release carries no Mix unless asked, and the console runs as
      # one (console/Dockerfile).
      extra_applications: [:logger, :runtime_tools, :inets, :ssl, :mix]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.12"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      # Colouring the code a cartridge writes. One lexer per language, and
      # the same token vocabulary out of all of them, so the palette is
      # written once and a new language costs no CSS. When a file turns
      # up that no makeup_* covers, makeup_syntect (the Sublime grammars
      # through a precompiled Rust NIF) is the escape hatch: Markdown and
      # the shell read through it (no makeup_* lexes a shell, checked on
      # hex 2026-09-29). An unknown extension is shown plain, never guessed at.
      # The papers a box carries, rendered escaping the HTML in them (console/README.md).
      {:mdex, "~> 0.13"},
      # The workbench's own package: the catalog is read in this BEAM, off the
      # cartridges' manifests, never off a project (console/PLAN.md).
      {:workbench_igniter, path: "../igniter"},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_eex, "~> 2.0"},
      {:makeup_html, "~> 0.2"},
      {:makeup_js, "~> 0.1"},
      {:makeup_json, "~> 1.0"},
      {:makeup_ts, "~> 0.2"},
      {:makeup_css, "~> 0.2"},
      {:makeup_syntect, "~> 0.1"},
      # makeup_syntect asks for rustler_precompiled 0.8 and mdex_native for
      # 0.9; the two differ in nothing either uses, so the newer one is kept.
      {:rustler_precompiled, "~> 0.9", override: true},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      # Static checks, run by CI: style and consistency, then success typing.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["compile", "esbuild console"],
      "assets.deploy": [
        "esbuild console --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
