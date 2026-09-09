defmodule WorkbenchIgniter.BirthTest do
  @moduledoc false

  # The birth is read off the first commit, so a repository is made for
  # each case: the files as phx.new leaves them, committed, then moved.

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Birth

  @mix """
  defmodule LoremIpsum.MixProject do
    use Mix.Project

    def project do
      [app: :lorem_ipsum, version: "0.1.0", deps: deps()]
    end

    defp deps do
      [
        {:phoenix, "~> 1.8.13"},
        {:phoenix_ecto, "~> 4.5"},
        {:ecto_sql, "~> 3.13"},
        {:postgrex, ">= 0.0.0"},
        {:phoenix_html, "~> 4.1"},
        {:phoenix_live_view, "~> 1.1.0"},
        {:phoenix_live_dashboard, "~> 0.8.3"},
        {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
        {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
        {:swoosh, "~> 1.16"},
        {:gettext, "~> 0.26"},
        {:bandit, "~> 1.5"}
      ]
    end
  end
  """

  @config """
  import Config

  config :lorem_ipsum,
    ecto_repos: [LoremIpsum.Repo],
    generators: [timestamp_type: :utc_datetime, binary_id: true]

  config :phoenix_live_view,
    debug_heex_annotations: true
  """

  @dockerfile """
  ARG ELIXIR="1.19.6"
  ARG    OTP="28.5.0.6"
  ARG DEBIAN="trixie-20260824-slim"
  ARG PHX_NEW="1.8.13"
  """

  setup do
    dir = Path.join(System.tmp_dir!(), "wb_birth_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "config"))
    File.write!(Path.join(dir, "mix.exs"), @mix)
    File.write!(Path.join(dir, "config/config.exs"), @config)
    File.write!(Path.join(dir, "Dockerfile.local"), @dockerfile)
    File.write!(Path.join(dir, "AGENTS.md"), "# Agents\n")
    git!(dir, ~w(init -q))
    git!(dir, ~w(add -A))
    git!(dir, ["commit", "-q", "-m", "New project: lorem_ipsum"])
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "reads phx.new's shape and the stamps off the first commit", %{dir: dir} do
    birth = Birth.read(dir)

    assert %{subject: "New project: lorem_ipsum", sha: sha, date: date} = birth
    assert String.length(sha) == 40 and String.match?(date, ~r/^\d{4}-\d{2}-\d{2} /)

    assert %{
             app: :lorem_ipsum,
             module: LoremIpsum,
             ecto: true,
             database: "postgres",
             adapter: "bandit",
             mailer: true,
             live: true,
             dashboard: true,
             binary_id: true,
             agents_md: true
           } = birth.phx

    assert birth.phx.flags ==
             ~w(--app lorem_ipsum --module LoremIpsum --database postgres --adapter bandit --binary-id)

    assert birth.dockerfile == %{
             "ELIXIR" => "1.19.6",
             "OTP" => "28.5.0.6",
             "DEBIAN" => "trixie-20260824-slim",
             "PHX_NEW" => "1.8.13"
           }
  end

  test "what moved since is not the birth's business", %{dir: dir} do
    # swoosh goes by hand, the stack moves, AGENTS.md is deleted: a second
    # commit. The birth still says what the first one said.
    File.write!(Path.join(dir, "mix.exs"), String.replace(@mix, "{:swoosh, \"~> 1.16\"},\n", ""))

    File.write!(
      Path.join(dir, "Dockerfile.local"),
      String.replace(@dockerfile, "1.19.6", "1.19.7")
    )

    File.rm!(Path.join(dir, "AGENTS.md"))
    git!(dir, ~w(add -A))
    git!(dir, ["commit", "-q", "-m", "By hand"])

    birth = Birth.read(dir)
    assert %{mailer: true, agents_md: true} = birth.phx
    assert birth.dockerfile["ELIXIR"] == "1.19.6"
    assert birth.subject == "New project: lorem_ipsum"
  end

  test "nil without a repository, or when the first commit has no mix.exs" do
    dir = Path.join(System.tmp_dir!(), "wb_birth_none_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    assert Birth.read(dir) == nil

    git!(dir, ~w(init -q))
    File.write!(Path.join(dir, "README.md"), "imported\n")
    git!(dir, ~w(add -A))
    git!(dir, ["commit", "-q", "-m", "Initial commit"])
    assert Birth.read(dir) == nil
  end

  defp git!(dir, args) do
    env = [
      {"GIT_AUTHOR_NAME", "Test"},
      {"GIT_AUTHOR_EMAIL", "test@localhost"},
      {"GIT_COMMITTER_NAME", "Test"},
      {"GIT_COMMITTER_EMAIL", "test@localhost"}
    ]

    {_, 0} = System.cmd("git", ["-C", dir | args], env: env, stderr_to_stdout: true)
  end
end
