defmodule WorkbenchIgniter.CatalogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  # A cartridge-shaped module with a boolean on by default, for the
  # rendering rule no cartridge exercises any more.
  defmodule Toggle do
    def name, do: "toggle"

    def info(_argv, _composing),
      do: %Igniter.Mix.Task.Info{schema: [thing: :boolean], defaults: [thing: true]}

    def option_docs, do: [thing: "Something on by default."]
    def choices, do: []
  end

  import ExUnit.CaptureIO
  import Igniter.Test

  alias WorkbenchIgniter.Features

  # Every cartridge there is, by directory name, in shelf order: the
  # collection first, then the cartridges, then the base ones.
  @cartridges ~w(chiefs_setup ansi version_manager toolchain versioning
                 dashboard_extras credo mock exdebug rest graphql
                 coveralls exdoc guidelines enhancements auth0 openai healthcheck stripe
                 githooks exmachina clustering healthcheck2 ash specdd db_admin k6 monitoring
                 mailer gettext ecto esbuild tailwind html dashboard)
  # The chiefs_setup recipe with its default choices, in insertion order.
  @picks ~w(ansi version_manager toolchain versioning dashboard_extras db_admin credo mock
            exdebug rest coveralls exdoc enhancements healthcheck)
  # Base cartridges a default phx.new project already carries.
  @in_by_default ~w(mailer gettext ecto esbuild tailwind html dashboard)

  describe "the catalog" do
    test "names every cartridge, in shelf order" do
      assert Enum.map(Features.catalog(), & &1.name()) == @cartridges

      assert for(e <- Enum.map(Features.catalog(), &Features.entry/1), e.base, do: e.name) ==
               @in_by_default

      assert Features.entry(Features.Ecto).afterwards =~ "./wb.sh setup"
      assert Features.entry(Features.Mailer).afterwards == nil
      assert Features.named("credo") == Features.Credo
      assert Features.named("nope") == nil
    end

    test "marks the collection and carries its default recipe" do
      assert %{collection: true, members: members} = Features.entry(Features.ChiefsSetup)
      assert Enum.map(members, & &1.name) == @picks
      # Each member with the argv its installer gets — the recipe.
      assert %{name: "rest", argv: ["--health"]} = Enum.find(members, &(&1.name == "rest"))
      assert %{name: "ansi", argv: []} = hd(members)
      assert %{collection: false, members: []} = Features.entry(Features.Clustering)

      # The recipe follows the collection's choice.
      members = for {name, _argv} <- Features.ChiefsSetup.members(interface: "graphql"), do: name
      assert "graphql" in members and "rest" not in members
    end

    test "each entry carries the manifest" do
      for feature <- Features.catalog(), entry = Features.entry(feature) do
        assert entry.name == feature.name()
        assert entry.task == "workbench.install." <> entry.name
        assert is_boolean(entry.collection)
        assert is_list(entry.requires)
        assert is_list(entry.options)

        unless entry.pending do
          assert is_binary(entry.summary), "#{entry.name} has no @shortdoc"
          assert is_binary(entry.example)
        end

        # The developer's need is part of the anatomy: one line the shelf
        # shows, off the cartridge's NEED.md, pending cartridges included.
        assert %{line: line, body: body, before: before, after: after_, not_for: not_for} =
                 entry.need,
               "#{entry.name} has no NEED.md"

        # The three paragraphs, each found and each one line.
        for {label, text} <- [{"Before", before}, {"After", after_}, {"Not for", not_for}] do
          assert is_binary(text) and text != "", "#{entry.name}'s NEED.md has no #{label}"
          refute text =~ "\n"
        end

        assert line =~ ~r/\S/ and not String.starts_with?(line, "**")
        assert body =~ "**Before:**" and body =~ "**After:**" and body =~ "**Not for:**"
      end
    end

    test "reads the version off the cartridge changelog" do
      assert %{version: %{version: "0.1.0", date: "2026-08-28"}} =
               Features.entry(Features.Healthcheck2)

      assert %{version: nil} = Features.entry(Features.Credo)
    end

    test "lists the installer's options with their defaults" do
      assert %{options: [%{name: :path, type: :string, default: "/health", choices: nil}]} =
               Features.entry(Features.Healthcheck2)

      assert %{pending: true, options: [], example: nil, requires: ["auth0"]} =
               Features.entry(Features.Stripe)
    end

    test "carries the values an option takes, closed or open, flat or in sections" do
      options = Features.entry(Features.Ash).options
      by = fn name -> Enum.find(options, &(&1.name == name)) end

      values = fn o -> Enum.map(o.choices, & &1.value) end

      assert %{open: false, multiple: true} = by.(:data_layer)
      assert values.(by.(:data_layer)) == ~w(postgres sqlite csv none)

      assert %{value: "postgres", doc: "ash_postgres · The swiss army knife" <> _} =
               hd(by.(:data_layer).choices)

      assert %{value: "none", doc: "no data layer — alone"} = List.last(by.(:data_layer).choices)
      assert %{open: false, multiple: true} = by.(:api)
      assert values.(by.(:api)) == ~w(json_api graphql typescript)

      assert %{
               choices: [%{value: "password", doc: "Allow users to log in" <> _} | _],
               open: true,
               multiple: true
             } = by.(:auth)

      assert %{doc: nil} = Enum.find(by.(:auth).choices, &(&1.value == "webauthn"))

      assert %{
               choices: [
                 %{
                   group: :ai,
                   values: [
                     %{value: "tidewave", doc: "Speed up development" <> _},
                     %{value: "ash_ai", doc: "First class support" <> _} | _
                   ]
                 }
                 | _
               ],
               open: true
             } = by.(:with)

      assert %{choices: nil, multiple: false} = by.(:example)

      theme = Enum.find(Features.entry(Features.Coveralls).options, &(&1.name == :theme))
      assert %{open: false} = theme

      assert [%{value: "exdoc-ish", doc: "mimics" <> _}, %{value: "custom", doc: _}] =
               theme.choices
    end

    test "documents its options from the cartridge, into the task's moduledoc" do
      for feature <- Features.catalog(), not feature.pending?() do
        keys = Keyword.keys(feature.info([], nil).schema || [])

        for {key, doc} <- feature.option_docs() do
          assert key in keys, "#{feature.name()} documents --#{key}, which its schema lacks"
          assert is_binary(doc) and doc != ""
        end
      end

      # Rendered: --no- for a boolean that defaults to true, wrapped bullets.
      assert WorkbenchIgniter.Feature.options_doc(Toggle) =~ ~r/^\* `--no-thing` - Something on/m

      assert WorkbenchIgniter.Feature.options_doc(Features.Healthcheck2) =~
               ~r/^\* `--path` - Prefix/

      # And in the task's own docs, interpolations resolved.
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} =
        Code.fetch_docs(Mix.Tasks.Workbench.Install.Coveralls)

      assert doc =~ "* `--theme` - HTML report theme, one of `custom`, `exdoc-ish`:"

      assert %{options: [%{name: :path, doc: "Prefix of the two probe routes" <> _}]} =
               Features.entry(Features.Healthcheck2)
    end

    test "says whether a second run adds or is a no-op, and what an adding one carries" do
      assert Features.Ash.rerun() == :adds
      assert Features.Healthcheck2.rerun() == :noop
      assert %{rerun: :adds} = Features.entry(Features.Ash)

      # A project with Ash, its Postgres layer, one API and one advanced
      # package: the state reads them off mix.exs, and nothing else.
      project =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ash, "~> 3.0"})
        |> Igniter.Project.Deps.add_dep({:ash_postgres, "~> 2.0"})
        |> Igniter.Project.Deps.add_dep({:ash_json_api, "~> 1.0"})
        |> Igniter.Project.Deps.add_dep({:ash_admin, "~> 0.13"})
        |> apply_igniter!()

      assert {%{data_layer: ["postgres"], api: ["json_api"], with: ["ash_admin"]}, _} =
               Features.Ash.state(project)

      assert {state, _} = Features.Ash.state(phx_test_project())
      assert state == %{}

      {status, _} = Features.status(project)

      assert %{installed: true, state: %{data_layer: ["postgres"]}} =
               Enum.find(status, &(&1.name == "ash"))

      assert %{installed: false, state: %{}} = Enum.find(status, &(&1.name == "credo"))
    end

    test "mix workbench.catalog --json prints it, with the covers when asked" do
      covers = Path.join(System.tmp_dir!(), "wb-catalog-#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(covers, "credo/sealed"))
      File.write!(Path.join(covers, "credo/sealed/cover.jpg"), "")

      output =
        capture_io(fn -> Mix.Tasks.Workbench.Catalog.run(["--json", "--covers", covers]) end)

      entries = Jason.decode!(output)

      assert Enum.map(entries, & &1["name"]) == @cartridges

      assert %{"covers" => %{"front" => "credo/sealed/cover.jpg", "back" => nil}} =
               Enum.find(entries, &(&1["name"] == "credo"))

      assert %{"covers" => %{"front" => nil, "back" => nil}} =
               Enum.find(entries, &(&1["name"] == "healthcheck2"))
    after
      :ok
    end

    test "mix workbench.catalog prints a table" do
      output = capture_io(fn -> Mix.Tasks.Workbench.Catalog.run([]) end)

      # The facts column says what is true of the box, and nothing when
      # nothing is — there is no kind to print.
      assert output =~ ~r/^chiefs_setup +v\d+\.\d+\.\d+ +inserts 14 +Your project is vanilla/m
      assert output =~ ~r/^mailer +\S+ +base +You want to see the mail/m
      assert output =~ ~r/^stripe +- +pending +Your users should be able to pay/m
      assert output =~ ~r/^healthcheck2 +v0\.1\.0 +Your platform polls/m
      assert output =~ ~r/^credo +- +You want a reviewer/m
    end
  end

  describe "installed?/1" do
    test "is false on a fresh project, for every cartridge phx.new does not bring" do
      {status, _igniter} = Features.status(phx_test_project())

      assert Enum.map(status, & &1.name) == @cartridges
      assert Enum.filter(status, & &1.installed) |> Enum.map(& &1.name) == @in_by_default
    end

    # The mark each installer's guard reads is what installed?/1 reads:
    # after applying the cartridge, the project carries it and nothing
    # else — the check of one cartridge never lights up another's.
    # ash is the exception: its mark (the `ash` dependency) is put by
    # the `mix igniter.install` command it queues, which runs after the
    # patch set and never in test mode; its own test covers the read.
    for feature <- Features.catalog(), not feature.pending?(), feature != Features.Ash do
      @feature feature
      test "flips for #{feature.name()} once it is installed, and for it alone" do
        igniter =
          Enum.reduce(
            prereqs(@feature.name()) ++ [@feature.task()],
            phx_test_project(),
            fn task, igniter -> Igniter.compose_task(igniter, task, args(task)) end
          )

        installed =
          igniter
          |> apply_igniter!()
          |> Features.status()
          |> elem(0)
          |> Enum.filter(& &1.installed)
          |> Enum.map(& &1.name)

        assert @feature.name() in installed
        others = (installed -- [@feature.name()]) -- @in_by_default

        # Nothing lights up that the manifest does not account for;
        # what it does account for may stay out (coveralls composes
        # mock with --exdoc alone).
        assert others -- others_installed(@feature.name()) == [],
               "#{@feature.name()} inserted #{inspect(others)}, more than it declares"

        if @feature.name() == "chiefs_setup",
          do: assert(others == others_installed("chiefs_setup"))
      end
    end

    # What a cartridge builds on must be in first (the installer
    # refuses otherwise): auth0 on enhancements, openai on both,
    # guidelines on the docs site it appends its page to.
    defp prereqs("auth0"), do: ["workbench.install.enhancements"]
    defp prereqs("openai"), do: ["workbench.install.enhancements", "workbench.install.auth0"]
    defp prereqs("guidelines"), do: ["workbench.install.exdoc"]
    defp prereqs(_name), do: []

    # The arguments an installer cannot do without. guidelines takes the
    # URL of the page it installs, and gets an unreachable one: the
    # download fails fast, offline, and its placeholder is planted —
    # which is the file the mark reads either way.
    defp args("workbench.install.guidelines"), do: ["--url", "http://localhost:1/guide.md"]
    defp args(_task), do: []

    # What may light up beside the cartridge, in catalog order, and all
    # of it off the manifest: what it requires (composed above as
    # prerequisites), what its installer composes (mock rides along
    # with healthcheck, coveralls and enhancements), and what those
    # stand on in turn. A cartridge that inserts more than it declares
    # fails above. The collection is the exception: every member of its
    # recipe, which the status lists in catalog order, not the recipe's.
    defp others_installed("chiefs_setup"), do: Enum.filter(@cartridges, &(&1 in @picks))
    defp others_installed(name), do: Enum.filter(@cartridges, &(&1 in stands_on(name)))

    defp stands_on(name) do
      entry = Features.entry(Features.named(name))
      direct = entry.requires ++ entry.composes
      Enum.uniq(direct ++ Enum.flat_map(direct, &stands_on/1))
    end
  end

  describe "state/1" do
    # Every cartridge with options, inserted with values none of which
    # is the default, then asked what the project carries: the answer
    # has the schema's keys, and says each value back — or `nil` for an
    # option that leaves no mark the project keeps, with the reason
    # here. The argv of each run and what state/1 must answer; a second
    # run reads the marks the first one's choices leave out. A cartridge
    # with options and no run here does not compile the suite. ash's
    # mark is put by the install it queues (its own test covers the
    # read); ecto is in from birth, and its test reads it off phx.new's
    # project.
    @runs %{
      "chiefs_setup" => [{~w(--interface graphql), %{interface: "graphql"}}],
      "version_manager" => [{~w(--manager mise), %{manager: "mise"}}],
      # On Postgres the default is pgadmin; the answer is in the shelf's order.
      "db_admin" => [
        {~w(--admin cloudbeaver,adminer), %{admin: ~w(adminer cloudbeaver)}}
      ],
      "versioning" => [
        {~w(--init-version 1.2.3 --mix-task --readme-badge),
         %{init_version: "1.2.3", mix_task: true, readme_badge: true}}
      ],
      "rest" => [
        {~w(--project-name Probe --auth0 --openai --health),
         %{project_name: "Probe", auth0: true, openai: true, health: true}}
      ],
      "coveralls" => [
        # --build runs the suite once; cover/ is gitignored.
        {~w(--minimum-coverage 90 --interface graphql --exdoc --theme custom --build),
         %{minimum_coverage: "90", interface: "graphql", exdoc: true, theme: "custom", build: nil}}
      ],
      "exdoc" => [
        # --version stamps the gitignored doc/ dummies only; --build runs mix docs once.
        {~w(--project-name Probe --version 9.9.9 --repo-url https://example.com/acme/probe
            --coveralls --auth0 --build),
         %{
           project_name: "Probe",
           version: nil,
           repo_url: "https://example.com/acme/probe",
           coveralls: true,
           auth0: true,
           build: nil
         }}
      ],
      # The page is the download; the URL is kept nowhere.
      "guidelines" => [{~w(--url http://localhost:1/guide.md), %{url: nil}}],
      "enhancements" => [
        # graphql: the REST group is not written, so --interface and
        # --health leave nothing to read; --stripe never does (its
        # diagrams are auth0's).
        {~w(--project-name Probe --id-type binary_id --timestamps utc_datetime_usec
            --interface graphql --exdoc --auth0 --openai --stripe --health),
         %{
           project_name: "Probe",
           id_type: "binary_id",
           timestamps: "utc_datetime_usec",
           interface: nil,
           exdoc: true,
           auth0: true,
           openai: true,
           stripe: nil,
           health: nil
         }},
        # rest: the error view and the Postman collection carry the rest.
        {~w(--project-name Probe --interface rest --auth0 --health),
         %{
           project_name: "Probe",
           id_type: "uuid",
           timestamps: "naive_datetime_usec",
           interface: "rest",
           exdoc: false,
           auth0: true,
           openai: false,
           stripe: nil,
           health: true
         }}
      ],
      # --project-name is read by no template of auth0 or openai; graphql
      # installs nothing none does not, so only rest is readable.
      "auth0" => [
        {~w(--project-name Probe --interface graphql), %{project_name: nil, interface: nil}},
        {~w(--interface rest), %{project_name: nil, interface: "rest"}}
      ],
      "openai" => [
        {~w(--project-name Probe --interface graphql), %{project_name: nil, interface: nil}},
        {~w(--interface rest), %{project_name: nil, interface: "rest"}}
      ],
      "healthcheck" => [
        {~w(--endpoint /health3 --open-api), %{endpoint: "/health3", open_api: true}}
      ],
      "clustering" => [{~w(--dns-query probe.internal), %{dns_query: "probe.internal"}}],
      "healthcheck2" => [{~w(--path /alive), %{path: "/alive"}}]
    }

    for feature <- Features.catalog(),
        not feature.pending?(),
        feature not in [Features.Ash, Features.Ecto, Features.Html],
        (feature.info([], nil).schema || []) != [] do
      @feature feature

      for {{argv, expected}, n} <- Enum.with_index(Map.fetch!(@runs, feature.name()), 1) do
        @argv argv
        @expected expected
        @n n
        test "#{feature.name()} says back what it was inserted with (run #{n})" do
          %{schema: schema, defaults: defaults} = @feature.info([], nil)

          # The first run asks for no default: an option answered with
          # its default would not show the read.
          if @n == 1 do
            for {key, default} <- defaults || [], not is_nil(@expected[key]) do
              refute @expected[key] == default,
                     "#{@feature.name()}'s run asks --#{key} for its default"
            end
          end

          igniter =
            Enum.reduce(
              prereqs(@feature.name()) ++ [{@feature.task(), @argv}],
              phx_test_project(),
              fn
                {task, argv}, igniter -> Igniter.compose_task(igniter, task, argv)
                task, igniter -> Igniter.compose_task(igniter, task, args(task))
              end
            )

          {state, _igniter} = igniter |> apply_igniter!() |> @feature.state()

          assert Enum.sort(Map.keys(state)) == Enum.sort(Keyword.keys(schema)),
                 "#{@feature.name()}'s state/1 does not answer for its schema"

          assert state == @expected
        end
      end
    end

    test "is the catalog's answer for what is not installed: nothing" do
      {status, _} = Features.status(phx_test_project())
      assert %{installed: false, state: %{}} = Enum.find(status, &(&1.name == "rest"))
    end
  end

  describe "composes" do
    test "names, off the installer's info, the cartridges it inserts along" do
      assert %{composes: ["mock"]} = Features.entry(Features.Healthcheck)
      assert %{composes: ["mock"]} = Features.entry(Features.Coveralls)
      assert %{composes: ["mock"]} = Features.entry(Features.Enhancements)
      assert %{composes: []} = Features.entry(Features.Credo)
      assert %{composes: []} = Features.entry(Features.Stripe)
    end

    # The installer's source is the check: every workbench task it
    # composes by name is in the declaration, and nothing else is.
    test "every compose_task of an installer is declared" do
      # The collection composes its members' tasks by name: its recipe
      # is `members/1`, checked above.
      for feature <- Features.catalog(),
          not feature.pending?(),
          feature != Features.ChiefsSetup do
        composed =
          feature.__info__(:compile)[:source]
          |> File.read!()
          |> then(&Regex.scan(~r/compose_task\(\s*"workbench\.install\.(\w+)"/, &1))
          |> Enum.map(fn [_, name] -> name end)
          |> Enum.sort()

        assert composed == Enum.sort(Features.entry(feature).composes),
               "#{feature.name()} composes #{inspect(composed)} and declares " <>
                 inspect(Features.entry(feature).composes)
      end
    end

    # What eject asks: a cartridge that brought another in stands on it
    # as much as one that required it.
    test "mix workbench.dependents sees what a cartridge composes" do
      {status, _} =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.healthcheck", [])
        |> apply_igniter!()
        |> Features.status()

      assert Mix.Tasks.Workbench.Dependents.dependents(status, "mock") == ["healthcheck"]
      assert Mix.Tasks.Workbench.Dependents.dependents(status, "healthcheck") == []
    end
  end
end
