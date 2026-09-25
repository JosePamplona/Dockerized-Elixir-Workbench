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
      [{"workbench.igniter_install", args}] -> args
      other -> flunk("expected one queued workbench.igniter_install, got #{inspect(other)}")
    end
  end

  defp files(igniter), do: igniter.assigns[:test_files]

  # A phx.new project on another adapter: its driver in place of postgrex.
  defp on(driver) do
    phx_test_project()
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.add_dep({driver, "~> 0.1"})
    |> apply_igniter!()
  end

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
      assert by["password"] == ["html", "mailer"]
      assert by["magic_link"] == ["html", "mailer"]
      assert by["api_key"] == []
      assert by["oauth2"] == ["html"]

      options = Map.new(WorkbenchIgniter.Features.entry(Ash).options, &{&1.name, &1})
      assert Enum.find(options.dev_tools.choices, &(&1.value == "ash_admin")).requires == ["html"]
      assert Enum.find(options.finance.choices, &(&1.value == "ash_money")).requires == []
    end

    test "refuses a strategy that needs live and a mailer the project lacks, naming them" do
      igniter = install(~w(--auth password), bare(~w(--no-live --no-mailer)))
      assert [issue] = igniter.issues
      assert issue =~ "--auth password builds on html with live and mailer"
      assert issue =~ "this project's live is off, and mailer is not in yet"
      assert issue =~ "./wb.sh add html --live, then ./wb.sh add mailer"
      assert igniter.tasks == []
    end

    test "api_key alone asks for nothing; the rest is fine on a default project" do
      args = queued(install(~w(--auth api_key), bare(~w(--no-live --no-mailer))))
      assert Enum.take(args, 3) == ~w(ash ash_phoenix ash_authentication)
      refute "ash_authentication_phoenix" in args
      assert "ash_admin" in queued(install(~w(--auth password --dev-tools ash_admin)))
    end
  end

  describe "the command" do
    test "with no option, ash and phoenix, with no data layer" do
      assert queued(install()) == ~w(ash ash_phoenix)
    end

    test "maps the site's choices to packages, in order" do
      args =
        install(
          ~w(--data-layer sqlite --api json_api,graphql --auth password,magic_link --dev-tools ash_admin --automation ash_oban),
          on(:ecto_sqlite3)
        )
        |> queued()

      assert args ==
               ~w(ash ash_sqlite ash_phoenix ash_json_api ash_graphql ash_authentication ash_authentication_phoenix ash_oban oban_web ash_admin --auth-strategy password,magic_link)
    end

    # What the site's command adds beside a package, read off its feature
    # map (DESIGN.md [17]): the companions, in the site's order.
    test "puts in what the site puts in beside a package" do
      assert queued(
               install(~w(--security ash_cloak --finance ash_double_entry --automation ash_oban))
             ) ==
               ~w(ash ash_phoenix ash_money ash_double_entry ash_oban oban_web cloak ash_cloak)
    end

    test "a database data layer builds on ecto with its own database" do
      data_layer =
        Enum.find(WorkbenchIgniter.Features.entry(Ash).options, &(&1.name == :data_layer))

      by = Map.new(data_layer.choices, &{&1.value, &1.requires})
      assert by == %{"postgres" => ["ecto"], "sqlite" => ["ecto"], "csv" => []}

      assert queued(install(~w(--data-layer sqlite,csv), on(:ecto_sqlite3))) ==
               ~w(ash ash_sqlite ash_csv ash_phoenix)
    end

    test "refuses a data layer on another database, before anything is queued" do
      igniter = install(~w(--data-layer postgres), on(:ecto_sqlite3))
      assert [issue] = igniter.issues
      assert issue =~ "--data-layer postgres builds on ecto with database postgres"
      assert issue =~ "this project's database is sqlite3"
      assert igniter.tasks == []
    end

    test "postgres and sqlite never go in together: a project has one database" do
      igniter = install(~w(--data-layer postgres,sqlite))
      assert [issue] = igniter.issues
      assert issue =~ "--data-layer sqlite builds on ecto with database sqlite3"
      assert igniter.tasks == []
    end

    test "a database data layer on a project without Ecto asks for it first" do
      igniter = install(~w(--data-layer postgres), bare(~w(--no-ecto)))
      assert [issue] = igniter.issues
      assert issue =~ "--data-layer postgres builds on ecto"
      assert issue =~ "./wb.sh add ecto"
      assert igniter.tasks == []

      assert queued(install(~w(--data-layer csv), bare(~w(--no-ecto)))) ==
               ~w(ash ash_csv ash_phoenix)
    end

    test "ash_events brings the postgres data layer, before authentication" do
      assert queued(install(~w(--automation ash_events --auth password))) ==
               ~w(ash ash_postgres ash_phoenix ash_authentication ash_authentication_phoenix ash_events --auth-strategy password)

      assert queued(install(~w(--data-layer postgres --automation ash_events))) ==
               ~w(ash ash_postgres ash_phoenix ash_events)

      automation =
        Enum.find(WorkbenchIgniter.Features.entry(Ash).options, &(&1.name == :automation))

      events = Enum.find(automation.choices, &(&1.value == "ash_events"))
      assert events.requires == ["ecto"]
      assert events.doc =~ "Runs on postgres only"
    end

    test "ash_events is refused on a SQLite project, and beside the sqlite data layer" do
      igniter = install(~w(--data-layer sqlite --automation ash_events), on(:ecto_sqlite3))
      assert [issue] = igniter.issues
      assert issue =~ "--automation ash_events builds on ecto with database postgres"
      assert igniter.tasks == []
    end

    test "hands ash_typescript the site's --framework react" do
      assert queued(install(~w(--api typescript))) ==
               ~w(ash ash_phoenix ash_typescript --framework react)
    end

    test "refuses --api typescript where ash_typescript would not find the web layer" do
      # :lorem_ipsum_2 is LoremIpsum2Web, which underscores to lorem_ipsum2_web.
      igniter = install(~w(--api json_api,typescript), phx_test_project(app_name: :lorem_ipsum_2))
      assert [issue] = igniter.issues
      assert issue =~ "--api typescript cannot go into this project"
      assert issue =~ "lib/lorem_ipsum2_web/"
      assert issue =~ "lib/lorem_ipsum_2_web/"
      assert igniter.tasks == []

      # The same name without typescript is fine.
      assert queued(install(~w(--api json_api), phx_test_project(app_name: :lorem_ipsum_2))) ==
               ~w(ash ash_phoenix ash_json_api)
    end

    test "oauth2 brings both packages and no strategy: the provider is configured by hand" do
      assert queued(install(~w(--auth oauth2))) ==
               ~w(ash ash_phoenix ash_authentication ash_authentication_phoenix)

      assert queued(install(~w(--auth password,oauth2))) ==
               ~w(ash ash_phoenix ash_authentication ash_authentication_phoenix --auth-strategy password)
    end

    test "API keys alone bring ash_authentication without its Phoenix half" do
      assert queued(install(~w(--auth api_key))) ==
               ~w(ash ash_phoenix ash_authentication --auth-strategy api_key)

      assert queued(install(~w(--auth api_key,password))) ==
               ~w(ash ash_phoenix ash_authentication ash_authentication_phoenix --auth-strategy api_key,password)
    end

    test "accepts repeated csv switches" do
      assert queued(install(~w(--api json_api --api typescript))) ==
               ~w(ash ash_phoenix ash_json_api ash_typescript --framework react)
    end

    test "--data-layer takes several, in the site's order" do
      assert queued(install(~w(--data-layer csv,postgres))) ==
               ~w(ash ash_postgres ash_csv ash_phoenix)
    end

    test "none is a value no more: an unknown data layer" do
      assert Enum.any?(
               install(~w(--data-layer none)).issues,
               &(&1 =~ "Unknown --data-layer none")
             )
    end

    test "--example and --yes are handed down" do
      assert queued(install(~w(--example --yes))) ==
               ~w(ash ash_phoenix --example --yes)
    end

    test "touches no file" do
      install() |> assert_unchanged()
    end

    test "explains what was queued" do
      igniter = install(~w(--auth password))

      assert Enum.any?(
               igniter.notices,
               &(&1 =~
                   "mix igniter.install ash ash_phoenix ash_authentication ash_authentication_phoenix --auth-strategy password")
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

    test "a package a section does not offer is an issue that names the ones it does" do
      igniter = install(~w(--dev-tools ash_admin,phoenix_storybook))

      assert igniter.tasks == []

      assert Enum.any?(
               igniter.issues,
               &(&1 =~ "Unknown --dev-tools phoenix_storybook. One of: live_debugger, ash_admin.")
             )
    end

    test "a section takes its packages in the site's order, whatever order they are given in" do
      assert queued(install(~w(--ai usage_rules,tidewave))) ==
               ~w(ash ash_phoenix tidewave usage_rules)
    end
  end

  describe "packages already in mix.exs" do
    test "are left out of the command" do
      igniter = phx_test_project() |> with_deps([:ash, :ash_phoenix])

      assert queued(install(~w(--data-layer postgres --api graphql), igniter)) ==
               ~w(ash_postgres ash_graphql)
    end

    test "when nothing is left, nothing is queued and a notice says so" do
      igniter = phx_test_project() |> with_deps([:ash, :ash_postgres, :ash_phoenix])

      igniter = install([], igniter)

      assert igniter.tasks == []
      assert Enum.any?(igniter.notices, &(&1 =~ "nothing to install"))
      assert_unchanged(igniter)
    end

    test "an advanced package already there is left out too" do
      igniter = phx_test_project() |> with_deps([:ash_admin])

      assert queued(install(~w(--dev-tools ash_admin), igniter)) == ~w(ash ash_phoenix)
    end
  end

  describe "installed?/1" do
    test "reads the ash dependency" do
      assert {false, _} = Ash.installed?(phx_test_project())
      assert {true, _} = phx_test_project() |> with_deps([:ash]) |> Ash.installed?()
    end
  end

  describe "state/1" do
    # The user resource as ash_authentication.install writes it, trimmed.
    @user """
    defmodule Test.Accounts.User do
      use Ash.Resource, extensions: [AshAuthentication]

      authentication do
        tokens do
          enabled? true
        end

        strategies do
          password :password do
            identity_field :email

            resettable do
              password_reset_action_name :reset_password_with_token
            end
          end

          remember_me :remember_me

          magic_link do
            identity_field :email
          end

          # api keys
          api_key :api_key do
            api_key_relationship :valid_api_keys
          end
        end
      end
    end
    """

    test "reads the strategies off the user resource, in order" do
      assert Ash.strategies_in(@user) == ~w(password remember_me magic_link api_key)
      assert Ash.strategies_in("defmodule A do\nend\n") == []
    end

    test "reports auth with the resource's strategies, and none without ash_authentication" do
      igniter =
        phx_test_project()
        |> with_deps([:ash, :ash_postgres, :ash_json_api, :ash_authentication])
        |> Igniter.create_new_file("lib/test/accounts/user.ex", @user)
        |> apply_igniter!()

      assert {%{
                data_layer: ["postgres"],
                api: ["json_api"],
                auth: ~w(password remember_me magic_link api_key)
              }, _} = Ash.state(igniter)

      assert {state, _} = phx_test_project() |> with_deps([:ash]) |> Ash.state()
      assert state == %{}
    end

    test "leaves auth out when the resource is not where the installer puts it" do
      igniter = phx_test_project() |> with_deps([:ash, :ash_authentication])
      assert {state, _} = Ash.state(igniter)
      refute Map.has_key?(state, :auth)
    end
  end

  describe "origins/2" do
    # What an insert's commit added, as ash went in with these options:
    # the packages its command named, and what their installers added.
    @added ~w(ash ash_postgres ash_phoenix ash_authentication ash_authentication_phoenix picosat_elixir bcrypt_elixir)

    test "the packages the options named carry the command; the rest, its installers" do
      notes =
        WorkbenchIgniter.Feature.origins(
          Ash,
          ~w(--data-layer postgres --auth password --example),
          %{
            added: @added,
            phx_new: "1.8.14"
          }
        )

      for name <- ~w(ash ash_postgres ash_phoenix ash_authentication ash_authentication_phoenix) do
        assert notes[name] =~ "its options name it in the `mix igniter.install` it runs"
      end

      for name <- ~w(picosat_elixir bcrypt_elixir) do
        assert notes[name] =~ "at the request of the installer of a package that command named"
      end
    end

    test "the note names the command, not its argv: the row and the insert's line say the rest" do
      notes =
        WorkbenchIgniter.Feature.origins(Ash, ~w(--data-layer sqlite --auth password), %{
          added: ~w(ash_sqlite),
          phx_new: nil
        })

      refute notes["ash_sqlite"] =~ "ash_sqlite"
      refute notes["ash_sqlite"] =~ "--auth-strategy"
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
