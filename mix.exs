defmodule LoremIpsum.MixProject do
  use Mix.Project

  def project do
    [
      app: :lorem_ipsum,
      version: "0.0.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),

      # ExDoc documentation parameters
      name: "Lorem Ipsum",
      source_url: "https://github.com/JosePamplona/Dockerized-Elixir-Workbench",
      docs: [
        source_ref: "main",
        authors: ["JosePamplona"],
        homepage_url: "https://www.lorem-ipsum.com",
        logo: "assets/exdoc/images/app-logo.png",
        output: "priv/static/doc",
        main: "readme",
        assets: %{
          "assets/exdoc/config" => "/",
          "assets/exdoc/cover/html" => "/",
          "assets/exdoc/images" => "/assets",
          "assets/exdoc/js" => "/assets"
        },
        extras: [
          {"README.md",                 [title: "Overview"]},
          {"CHANGELOG.md",              [title: "Changelog"]},
          {"assets/exdoc/token.md",     [title: "Get access tokens"]},
          {"assets/exdoc/database.md",  [title: "Database"]},
          {"assets/exdoc/testing.md",   [title: "Tests reports"]},
          {"assets/exdoc/coding.md",    [title: "Coding guidelines"]},
          {"assets/exdoc/workbench.md", [title: "Workbench"]},
          {"assets/exdoc/CONFIG.md", [title: "Configuration File"]}
        ],
        groups_for_extras: [
          "Project": [
            "README.md",
            "CHANGELOG.md"
          ],
          "Support": [
            "assets/exdoc/token.md",
            "assets/exdoc/testing.md",
            "assets/exdoc/database.md",
            "assets/exdoc/coding.md",
            "assets/exdoc/workbench.md",
            "assets/exdoc/CONFIG.md"
          ]
        ],
        groups_for_modules: [
          "Contexts": ~r/^LoremIpsum\.(?!(.*\..*|Mailer|Repo|Helper|.*Ecto.*)$).*$/,
          "Schemas":  ~r/^LoremIpsum\..*\.(?!.*(Enum)$).*$/,
          "Types":    ~r/^LoremIpsum\..*(Enum|EctoURI)$/,
          "Web":         ~r/^LoremIpsumWeb(?!(.Plug..*|.*(Controller|HTML|JSON))$)/,
          "Plugs":       ~r/^LoremIpsumWeb.Plug..*$/,
          "Controllers": ~r/^LoremIpsumWeb.*(Controller)$/,
          "Views":       ~r/^LoremIpsumWeb.*(HTML|JSON)$/
        ],
        before_closing_head_tag: &before_closing_head_tag/1,
        before_closing_body_tag: &before_closing_body_tag/1
      ],

      # Coverage parameters
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        cover: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
      ]
    ]
  end

  defp before_closing_head_tag(:epub), do: ""
  defp before_closing_head_tag(:html), do: ""

  defp before_closing_body_tag(:epub), do: ""
  defp before_closing_body_tag(:html) do
    """
    <script src=./assets/themedImage.js></script>
    <script src=https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js></script>
    <script src=./assets/auth_config.js></script>
    <script src=./assets/token.js></script>
    """
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LoremIpsum.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
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
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # Enhancements implementation deps set
      {:ecto_psql_extras, "~> 0.8", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3",  only: :test},
      {:ex_debug, "~> 1.0"},
      {:ecto_enum, "~> 1.4"},
      {:html_entities, "~> 0.5"},
      # OpenAPI documentation deps
      {:open_api_spex, "~> 3.21"},
      # ExDoc documentation deps
      {:ex_doc, "~> 0.35.0", only: :dev, runtime: false},
      # Coverage report deps
      {:excoveralls, "~> 0.18", only: :test},
      # Auth0 API integration deps
      {:auth0_jwks, "~> 0.3"}
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind lorem_ipsum", "esbuild lorem_ipsum"],
      "assets.deploy": [
        "tailwind lorem_ipsum --minify",
        "esbuild lorem_ipsum --minify",
        "phx.digest"
      ]
    ]
  end
end
