defmodule WorkbenchIgniter.MixFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.MixFile

  @base """
  defmodule Test.MixProject do
    use Mix.Project

    def project do
      [
        app: :test,
        version: "0.1.0",
        elixir: "~> 1.15",
        aliases: aliases(),
        deps: deps()
      ]
    end

    defp deps do
      [
        {:phoenix, "~> 1.8.0"},
        {:bandit, "~> 1.5"}
      ]
    end

    defp aliases do
      [
        setup: ["deps.get", "assets.setup"],
        "assets.build": ["compile"]
      ]
    end
  end
  """

  # html, as phx.new writes it: a compiler, a dependency whose option
  # is an expression, an alias changed.
  @theirs @base
          |> String.replace(
            "      deps: deps()\n",
            "      deps: deps(),\n      compilers: [:phoenix_live_view] ++ Mix.compilers()\n"
          )
          |> String.replace(
            "      {:bandit, \"~> 1.5\"}\n",
            "      {:bandit, \"~> 1.5\"},\n      {:phoenix_live_reload, \"~> 1.2\", only: :dev},\n      {:phoenix_live_view, \"~> 1.1\", runtime: Mix.env() == :dev}\n"
          )
          |> String.replace(
            ~s|      "assets.build": ["compile"]\n|,
            ~s|      "assets.build": ["compile", "esbuild test"]\n|
          )

  # The project as the workbench leaves it at birth: the dependency on
  # the deps: line, its function before deps — and an edit of its own.
  @ours @base
        |> String.replace("      deps: deps()\n", "      deps: deps() ++ workbench_dep()\n")
        |> String.replace(
          "  defp deps do\n",
          "  # Workbench igniter tasks, available while the workbench is mounted.\n  defp workbench_dep do\n    path = \"\#{System.get_env(\"WORKBENCH_PATH\", \"/app/workbench\")}/igniter\"\n\n    if File.exists?(path) do\n      [{:workbench_igniter, path: path, only: [:dev, :test], runtime: false}]\n    else\n      []\n    end\n  end\n\n  defp deps do\n"
        )
        |> String.replace(
          "      {:bandit, \"~> 1.5\"}\n",
          "      {:bandit, \"~> 1.5\"},\n      {:req, \"~> 0.5\"}\n"
        )

  describe "read/1" do
    test "the project's keywords, its dependencies by name, its aliases" do
      read = MixFile.read(@ours)

      assert Keyword.keys(read.project) == [:app, :version, :elixir, :aliases, :deps]
      assert Keyword.keys(read.deps) == [:phoenix, :bandit, :req]
      assert Keyword.keys(read.aliases) == [:setup, :"assets.build"]
      assert Macro.to_string(read.project[:deps]) == "deps() ++ workbench_dep()"
    end
  end

  describe "diff/2" do
    test "what the capability adds or changes, and nothing it leaves alone" do
      delta = MixFile.diff(@base, @theirs)

      assert [{:compilers, compilers}] = delta.project
      assert Macro.to_string(compilers) == "[:phoenix_live_view] ++ Mix.compilers()"
      assert Keyword.keys(delta.deps) == [:phoenix_live_reload, :phoenix_live_view]
      assert [{:"assets.build", _}] = delta.aliases
    end
  end

  describe "apply/4" do
    test "puts the capability in beside the workbench's line and the project's own dependency" do
      igniter =
        test_project(files: %{"mix.exs" => @ours})
        |> MixFile.apply(@base, @theirs, "html cartridge")

      assert issues(igniter) == []

      assert_has_patch(igniter, "mix.exs", """
      10    - |      deps: deps() ++ workbench_dep()
         10 + |      deps: deps() ++ workbench_dep(),
         11 + |      compilers: [:phoenix_live_view] ++ Mix.compilers()
      """)

      mix = rewritten(igniter)

      # The workbench's line and function stay as they were.
      assert mix =~
               "deps: deps() ++ workbench_dep(),\n      compilers: [:phoenix_live_view] ++ Mix.compilers()"

      assert mix =~ "defp workbench_dep do"
      # The dependencies come in as written, expression included, after the project's.
      assert mix =~
               "{:req, \"~> 0.5\"},\n      {:phoenix_live_reload, \"~> 1.2\", only: :dev},\n      {:phoenix_live_view, \"~> 1.1\", runtime: Mix.env() == :dev}"

      # The alias the project kept as phx.new had it takes the capability's.
      assert mix =~ ~s|"assets.build": ["compile", "esbuild test"]|
      assert mix =~ ~s|setup: ["deps.get", "assets.setup"]|
    end

    test "applied twice, nothing doubles" do
      igniter =
        test_project(files: %{"mix.exs" => @ours})
        |> MixFile.apply(@base, @theirs, "html cartridge")
        |> apply_igniter!()
        |> MixFile.apply(@base, @theirs, "html cartridge")

      assert issues(igniter) == []
      assert_unchanged(igniter, "mix.exs")
    end

    test "a dependency the project already has, in its own version, stays" do
      ours = String.replace(@ours, "{:req, \"~> 0.5\"}", "{:phoenix_live_view, \"~> 1.0\"}")

      igniter =
        test_project(files: %{"mix.exs" => ours})
        |> MixFile.apply(@base, @theirs, "html cartridge")

      assert issues(igniter) == []
      mix = rewritten(igniter)
      assert mix =~ "{:phoenix_live_view, \"~> 1.0\"}"
      refute mix =~ "runtime: Mix.env() == :dev"
      assert mix =~ "{:phoenix_live_reload, \"~> 1.2\", only: :dev}"
    end

    test "a keyword the project changed from phx.new's own is the project's: an issue, not an overwrite" do
      ours =
        String.replace(
          @ours,
          ~s|"assets.build": ["compile"]|,
          ~s|"assets.build": ["compile", "my.assets"]|
        )

      igniter =
        test_project(files: %{"mix.exs" => ours})
        |> MixFile.apply(@base, @theirs, "html cartridge")

      assert [issue] = issues(igniter)
      assert issue =~ ~s|mix.exs: :aliases :"assets.build" is the project's own|
      assert issue =~ "html cartridge"
      # The rest went in all the same.
      mix = rewritten(igniter)
      assert mix =~ ~s|"assets.build": ["compile", "my.assets"]|
      assert mix =~ "compilers: [:phoenix_live_view] ++ Mix.compilers()"
    end

    test "a deps/0 that does not end in a list is an issue, naming the dependency" do
      ours =
        String.replace(
          @ours,
          "{:req, \"~> 0.5\"}\n    ]\n",
          "{:req, \"~> 0.5\"}\n    ] ++ more()\n"
        )

      igniter =
        test_project(files: %{"mix.exs" => ours})
        |> MixFile.apply(@base, @theirs, "html cartridge")

      # One per dependency: the reader knows each name it could not put in.
      assert Enum.sort(issues(igniter)) == [
               "mix.exs: `deps/0` does not end in a list literal to add :phoenix_live_reload to.",
               "mix.exs: `deps/0` does not end in a list literal to add :phoenix_live_view to."
             ]
    end
  end

  defp issues(igniter), do: Igniter.prepare_for_write(igniter).issues

  defp rewritten(igniter) do
    igniter.rewrite |> Rewrite.source!("mix.exs") |> Rewrite.Source.get(:content)
  end
end
