defmodule WorkbenchIgniter.Features.AshTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Ash

  # Every test runs against an in-memory Phoenix project (app: :test) —
  # no files are written and nothing is fetched: the cartridge's whole
  # output is the `mix igniter.install` command it queues.

  defp install(argv \\ [], igniter \\ phx_test_project()) do
    Igniter.compose_task(igniter, "workbench.install.ash", argv)
  end

  defp queued(igniter) do
    case igniter.tasks do
      [{"igniter.install", args}] -> args
      other -> flunk("expected one queued igniter.install, got #{inspect(other)}")
    end
  end

  defp files(igniter), do: igniter.assigns[:test_files]

  defp with_deps(igniter, deps) do
    deps
    |> Enum.reduce(igniter, &Igniter.Project.Deps.add_dep(&2, {&1, "~> 1.0"}))
    |> apply_igniter!()
  end

  describe "what the options build on" do
    defp bare(extra), do: WorkbenchIgniter.TestProject.new(extra)

    test "the catalog says it beside the value" do
      auth = Enum.find(WorkbenchIgniter.Features.entry(Ash).options, &(&1.name == :auth))
      by = Map.new(auth.choices, &{&1.value, &1.requires})
      assert by["password"] == ["live", "mailer"]
      assert by["magic_link"] == ["live", "mailer"]
      assert by["github"] == ["live"]
      assert by["api_key"] == []

      with_ = Enum.find(WorkbenchIgniter.Features.entry(Ash).options, &(&1.name == :with))
      values = Enum.flat_map(with_.choices, & &1.values)
      assert Enum.find(values, &(&1.value == "ash_admin")).requires == ["live"]
      assert Enum.find(values, &(&1.value == "ash_money")).requires == []
    end

    test "refuses a strategy that needs live and a mailer the project lacks, naming them" do
      igniter = install(~w(--auth password), bare(~w(--no-live --no-mailer)))
      assert [issue] = igniter.issues
      assert issue =~ "--auth password builds on live and mailer"
      assert issue =~ "./wb.sh add live"
      assert igniter.tasks == []
    end

    test "api_key alone asks for nothing; the rest is fine on a default project" do
      args = queued(install(~w(--auth api_key), bare(~w(--no-live --no-mailer))))
      assert Enum.take(args, 4) == ~w(ash ash_postgres ash_phoenix ash_authentication)
      refute "ash_authentication_phoenix" in args
      assert "ash_admin" in queued(install(~w(--auth password --with ash_admin)))
    end
  end

  describe "the command" do
    test "defaults to ash, postgres and phoenix" do
      assert queued(install()) == ~w(ash ash_postgres ash_phoenix)
    end

    test "maps the site's choices to packages, in order" do
      args =
        install(
          ~w(--data-layer sqlite --api json_api,graphql --auth password,magic_link --with ash_admin,ash_oban)
        )
        |> queued()

      assert args ==
               ~w(ash ash_sqlite ash_phoenix ash_json_api ash_graphql ash_authentication ash_authentication_phoenix ash_admin ash_oban oban_web --auth-strategy password,magic_link)
    end

    # What the site's command adds beside a package, read off its feature
    # map (DESIGN.md [17]): the companions, in the site's order.
    test "puts in what the site puts in beside a package" do
      assert queued(install(~w(--with ash_cloak,ash_double_entry,ash_oban))) ==
               ~w(ash ash_postgres ash_phoenix cloak ash_cloak ash_money ash_double_entry ash_oban oban_web)
    end

    test "hands ash_typescript the site's --framework react" do
      assert queued(install(~w(--api typescript))) ==
               ~w(ash ash_postgres ash_phoenix ash_typescript --framework react)
    end

    test "API keys alone bring ash_authentication without its Phoenix half" do
      assert queued(install(~w(--auth api_key))) ==
               ~w(ash ash_postgres ash_phoenix ash_authentication --auth-strategy api_key)

      assert queued(install(~w(--auth api_key,password))) ==
               ~w(ash ash_postgres ash_phoenix ash_authentication ash_authentication_phoenix --auth-strategy api_key,password)
    end

    test "accepts repeated csv switches" do
      assert queued(install(~w(--api json_api --api typescript))) ==
               ~w(ash ash_postgres ash_phoenix ash_json_api ash_typescript --framework react)
    end

    test "--data-layer takes several, in the site's order; none stands alone" do
      assert queued(install(~w(--data-layer csv,postgres))) ==
               ~w(ash ash_postgres ash_csv ash_phoenix)

      assert Enum.any?(install(~w(--data-layer postgres,none)).issues, &(&1 =~ "stands alone"))
    end

    test "--data-layer none leaves the data layer out" do
      assert queued(install(~w(--data-layer none))) == ~w(ash ash_phoenix)
    end

    test "--example and --yes are handed down" do
      assert queued(install(~w(--example --yes))) ==
               ~w(ash ash_postgres ash_phoenix --example --yes)
    end

    test "touches no file" do
      install() |> assert_unchanged()
    end

    test "explains what was queued" do
      igniter = install(~w(--auth password))

      assert Enum.any?(
               igniter.notices,
               &(&1 =~
                   "mix igniter.install ash ash_postgres ash_phoenix ash_authentication ash_authentication_phoenix --auth-strategy password")
             )
    end
  end

  describe "--auth" do
    test "writes TOKEN_SIGNING_SECRET to .env, generated, and blank to .env.sample" do
      files = install(~w(--auth password)) |> apply_igniter!() |> files()

      assert [_, secret] = Regex.run(~r/^TOKEN_SIGNING_SECRET="(\w{64})"$/m, files[".env"])
      assert String.length(secret) == 64
      assert files[".env.sample"] =~ ~s|\nTOKEN_SIGNING_SECRET=""\n|
      assert files[".env"] =~ "# Signs AshAuthentication's tokens"
    end

    test "appends to an existing .env and never twice" do
      igniter =
        install(
          ~w(--auth password),
          phx_test_project(
            files: %{".env" => ~s|PORT="4000"\n|, ".env.sample" => ~s|PORT="4000"\n|}
          )
        )
        |> apply_igniter!()

      env = files(igniter)[".env"]
      assert env =~ ~s|PORT="4000"\n\n# Signs|
      assert length(String.split(env, "TOKEN_SIGNING_SECRET=")) == 2

      install(~w(--auth password), igniter) |> assert_unchanged()
    end

    test "without --auth, no environment entry" do
      igniter = install() |> apply_igniter!()

      refute Map.has_key?(files(igniter), ".env")
    end
  end

  describe "unknown choices" do
    test "an unknown data layer is an issue, and nothing is queued" do
      igniter = install(~w(--data-layer mysql))

      assert igniter.tasks == []
      assert Enum.any?(igniter.issues, &(&1 =~ ~s|Unknown --data-layer mysql|))
    end

    test "an unknown api is an issue, and nothing is queued" do
      igniter = install(~w(--api soap,graphql))

      assert igniter.tasks == []
      assert Enum.any?(igniter.issues, &(&1 =~ "Unknown --api soap."))
    end
  end

  describe "packages already in mix.exs" do
    test "are left out of the command" do
      igniter = phx_test_project() |> with_deps([:ash, :ash_phoenix])

      assert queued(install(~w(--api graphql), igniter)) == ~w(ash_postgres ash_graphql)
    end

    test "when nothing is left, nothing is queued and a notice says so" do
      igniter = phx_test_project() |> with_deps([:ash, :ash_postgres, :ash_phoenix])

      igniter = install([], igniter)

      assert igniter.tasks == []
      assert Enum.any?(igniter.notices, &(&1 =~ "nothing to install"))
      assert_unchanged(igniter)
    end

    test "`org/package@version` specs are matched by their package name" do
      igniter = phx_test_project() |> with_deps([:ash_admin])

      assert queued(install(~w(--with acme/ash_admin@1.2), igniter)) ==
               ~w(ash ash_postgres ash_phoenix)
    end
  end

  describe "installed?/1" do
    test "reads the ash dependency" do
      assert {false, _} = Ash.installed?(phx_test_project())
      assert {true, _} = phx_test_project() |> with_deps([:ash]) |> Ash.installed?()
    end
  end

  describe "the manifest" do
    test "is a plain cartridge in the catalog, picked by no collection" do
      assert Ash in WorkbenchIgniter.Features.catalog()
      assert Ash.members([]) == []
      picks = WorkbenchIgniter.Features.entry(WorkbenchIgniter.Features.ChiefsSetup).members
      refute "ash" in Enum.map(picks, & &1.name)
    end
  end
end
