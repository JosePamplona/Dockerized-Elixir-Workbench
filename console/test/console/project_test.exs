defmodule Console.ProjectTest do
  use ExUnit.Case, async: true

  alias Console.Project

  @dockerfile """
  ARG ELIXIR="1.19.2"
  ARG    OTP="28.1"
  ARG DEBIAN="trixie-20251103-slim"

  ARG TOOLCHAIN_IMAGE="hexpm/elixir:${ELIXIR}-erlang-${OTP}-debian-${DEBIAN}"
  FROM ${TOOLCHAIN_IMAGE}
  ARG UID=1000
  ARG PHX_NEW="1.8.13"
  """

  setup do
    dir = Path.join(System.tmp_dir!(), "wb-project-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "what the project was made with, off its own Dockerfile", %{dir: dir} do
    File.write!(Path.join(dir, "Dockerfile.local"), @dockerfile)

    assert Project.born(dir) == %{
             "ELIXIR" => "1.19.2",
             # `ARG    OTP` is padded to line the three up in the file.
             "OTP" => "28.1",
             "DEBIAN" => "trixie-20251103-slim",
             "PHX_NEW" => "1.8.13"
           }
  end

  test "the build arguments that are not the stack stay out of it", %{dir: dir} do
    File.write!(Path.join(dir, "Dockerfile.local"), @dockerfile)
    refute Map.has_key?(Project.born(dir), "UID")
    refute Map.has_key?(Project.born(dir), "TOOLCHAIN_IMAGE")
  end

  test "no workspace, or one with no Dockerfile, answers nothing", %{dir: dir} do
    assert Project.born(nil) == nil
    assert Project.born(dir) == nil
  end

  test "the papers carried: the files it holds, Birth with a project, the git ones with a repository",
       %{dir: dir} do
    File.write!(Path.join(dir, "README.md"), "# Lorem\n")
    status = %{"exists" => true, "workspace" => dir, "git" => %{"repo" => true}}
    assert Project.carried(status) == ~w(record history pending readme)
    assert Project.carried(put_in(status, ["git", "repo"], false)) == ~w(record readme)
    assert Project.carried(%{"exists" => false, "workspace" => dir}) == []
    assert Project.carried(nil) == []
  end

  test "Mix is carried with a mix.exs, between Changes and .env", %{dir: dir} do
    File.write!(Path.join(dir, "mix.exs"), "defmodule M do\nend\n")
    File.write!(Path.join(dir, ".env"), "PORT=4000\n")
    status = %{"exists" => true, "workspace" => dir, "git" => %{"repo" => true}}
    assert Project.carried(status) == ~w(record history pending mix env)
  end

  test "Mix says what def project says, coloured, and each package's options", %{dir: dir} do
    File.write!(Path.join(dir, "mix.exs"), """
    defmodule Lorem.MixProject do
      use Mix.Project

      def project do
        [
          app: :lorem,
          version: "0.1.0",
          elixir: "~> 1.15",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      defp deps do
        [
          {:phoenix, "~> 1.8.0"},
          {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
          {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.2.0", app: false}
        ]
      end
    end
    """)

    %{mix: mix} = Project.render(dir, "mix")

    # The options alone: def project's keywords are no longer read.
    assert Map.keys(mix) == [:options]

    # The options, less where a git package comes from; none for phoenix.
    assert Map.keys(mix.options) |> Enum.sort() == ["credo", "heroicons"]
    # One to a line, as written, the inner list whole.
    assert mix.options["credo"] == "only: [:dev, :test],\nruntime: false"
    refute mix.options["heroicons"] =~ "github"
    assert mix.options["heroicons"] =~ "app"
  end

  test "who put each package in mix.exs: a box, the first commit, or a hand", %{dir: dir} do
    git = fn args -> System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) end
    git.(["init", "--quiet"])
    git.(["config", "user.email", "t@example.com"])
    git.(["config", "user.name", "T"])

    deps = fn list ->
      "defp deps do\n  [\n" <>
        Enum.map_join(list, ",\n", &"    {:#{&1}, \"~> 1.0\"}") <> "\n  ]\nend\n"
    end

    File.write!(Path.join(dir, "mix.exs"), deps.(~w(phoenix)))
    git.(["add", "."])
    git.(["commit", "--quiet", "-m", "Born"])
    {born, 0} = git.(["rev-parse", "HEAD"])

    File.write!(Path.join(dir, "mix.exs"), deps.(~w(phoenix swoosh)))
    git.(["commit", "--quiet", "-am", "Insert mailer"])
    {mailer, 0} = git.(["rev-parse", "HEAD"])

    File.write!(Path.join(dir, "mix.exs"), deps.(~w(phoenix swoosh credo tidewave)))
    git.(["commit", "--quiet", "-am", "Insert credo, and a hand"])

    status = %{
      "workspace" => dir,
      "git" => %{"inserts" => [%{"feature" => "mailer", "sha" => String.trim(mailer)}]},
      "project" => %{
        "birth" => %{"sha" => String.trim(born)},
        "cartridges" => [
          %{"name" => "mailer", "installed" => true, "deps" => []},
          %{
            "name" => "credo",
            "installed" => true,
            "deps" => [%{"name" => "credo", "declared" => "~> 1.7"}]
          }
        ],
        "deps" => Enum.map(~w(phoenix swoosh credo tidewave), &%{"name" => &1})
      }
    }

    by = Project.brought_by(status)

    assert Map.new(by, fn {name, reading} -> {name, reading["by"]} end) == %{
             "phoenix" => :born,
             "swoosh" => {:boxes, ["mailer"]},
             "credo" => {:boxes, ["credo"]},
             "tidewave" => :hand
           }

    # What the cartridge asks for comes along: a base box's off its
    # insert, marked as read there; a declaring box's its own pin.
    assert %{"declared" => "~> 1.0", "read" => true} = by["swoosh"]
    assert by["credo"]["declared"] == "~> 1.7"
  end

  test "no mix.exs, or one that does not read as code, is no Mix page", %{dir: dir} do
    assert Project.render(dir, "mix") == nil
    File.write!(Path.join(dir, "mix.exs"), "defmodule M do\n")
    assert Project.render(dir, "mix") == nil
  end
end
