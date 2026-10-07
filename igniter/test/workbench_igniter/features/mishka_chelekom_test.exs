defmodule WorkbenchIgniter.Features.MishkaChelekomTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias Mix.Tasks.Workbench.MishkaComponents
  alias WorkbenchIgniter.Features.MishkaChelekom

  # Every test runs against an in-memory phx.new project (app: :test):
  # nothing is fetched, and the library's task — queued — never runs.
  # What it writes was read off a real project (DESIGN.md, *Verified*).

  defp project(flags \\ []), do: WorkbenchIgniter.TestProject.new(flags)

  defp install(argv \\ [], igniter \\ project()) do
    Igniter.compose_task(igniter, "workbench.install.mishka_chelekom", argv)
  end

  defp files(igniter), do: igniter.assigns[:test_files]

  defp with_deps(igniter, deps) do
    deps
    |> Enum.reduce(igniter, &Igniter.Project.Deps.add_dep(&2, {&1, "~> 1.0"}))
    |> apply_igniter!()
  end

  # `mix mcp.json` is the project's file, planted verbatim: compiled
  # here once, to run what the project will run.
  setup_all do
    unless Code.ensure_loaded?(task()),
      do: Code.compile_string(MishkaChelekom.asset("mcp.json.ex"))

    :ok
  end

  # Named at run time: the module is the asset's, compiled above, and
  # no module of this package.
  defp task, do: Module.concat(Mix.Tasks.Mcp, Json)

  describe "mix workbench.install.mishka_chelekom" do
    test "adds the dependency and queues the library's task for every component" do
      igniter = install()

      assert_has_patch(igniter, "mix.exs", """
      + | {:mishka_chelekom, "~> 0.0.9", only: :dev}
      """)

      assert igniter.tasks == [{"workbench.mishka_components", ["--format"]}]
      assert Enum.any?(igniter.notices, &(&1 =~ "mix mishka.ui.gen.components --import"))
    end

    test "leaves daisyUI where it is" do
      css = install() |> apply_igniter!() |> files() |> Map.fetch!("assets/css/app.css")

      assert css =~ ~s(@plugin "daisyui/packages/bundle/daisyui")
      assert {%{no_daisy: false}, _} = install() |> apply_igniter!() |> MishkaChelekom.state()
    end

    test "is a no-op when the dependency is already present, and says how to add a component" do
      igniter = install(~w(--components card --no-daisy), apply_igniter!(install()))

      assert_unchanged(igniter)
      assert igniter.tasks == []
      assert Enum.any?(igniter.notices, &(&1 =~ "mix mishka.ui.gen.component NAME"))
    end

    # The ash cartridge's `--components mishka_chelekom` leaves the
    # same dependency: both roads light the same box.
    test "is in when the library came with another installer" do
      project = with_deps(project(), [:mishka_chelekom])

      assert {true, _} = MishkaChelekom.installed?(project)
      assert install([], project).tasks == []
    end
  end

  describe "what it builds on" do
    test "refuses without tailwind, naming it" do
      igniter = install([], project(~w(--no-tailwind)))

      assert [issue] = igniter.issues
      assert issue =~ "mishka_chelekom builds on tailwind"
      assert issue =~ "./wb.sh add tailwind"
      assert igniter.tasks == []
    end

    test "refuses without live" do
      igniter = install([], project(~w(--no-live)))

      assert [issue] = igniter.issues
      assert issue =~ "html with live"
    end

    test "refuses without esbuild: the hooks go into app.js" do
      assert [issue] = install([], project(~w(--no-esbuild))).issues
      assert issue =~ "esbuild"
    end
  end

  describe "--components" do
    test "hands the names to the queued task, as given" do
      assert install(~w(--components card,badge,card)).tasks ==
               [{"workbench.mishka_components", ~w(--format card badge)}]
    end

    test "refuses a name the library does not have, before anything is fetched" do
      igniter = install(~w(--components card,kard))

      assert [issue] = igniter.issues
      assert issue =~ "no component named kard"
      assert issue =~ "accordion, alert, avatar"
      assert igniter.tasks == []
    end

    test "the notice names what comes along" do
      [notice] = Enum.filter(install(~w(--components card)).notices, &(&1 =~ "gen.components"))

      assert notice =~
               "<card, what they need and alert,button,icon,input_field,list,modal,navbar,table>"
    end

    test "the catalog offers the library's names by its categories, and no other" do
      option =
        Enum.find(
          WorkbenchIgniter.Features.entry(MishkaChelekom).options,
          &(&1.name == :components)
        )

      assert Enum.map(option.choices, & &1.group) ==
               ~w(general navigations forms feedback overlays media)a

      values = for group <- option.choices, choice <- group.values, do: choice.value
      assert length(values) == 74
      assert "timeline" in values
      assert Enum.uniq(values) == values
      refute option.open
    end

    test "each name carries its page in the library's documentation, and the note the site" do
      option =
        Enum.find(
          WorkbenchIgniter.Features.entry(MishkaChelekom).options,
          &(&1.name == :components)
        )

      docs =
        for group <- option.choices,
            choice <- group.values,
            into: %{},
            do: {choice.value, choice.doc}

      assert docs["navbar"] == "https://mishka.tools/chelekom/docs/navbar"
      assert docs["device_mockup"] == "https://mishka.tools/chelekom/docs/device-mockup"
      # The forms have a shelf of their own there, and two a name of their own.
      assert docs["text_field"] == "https://mishka.tools/chelekom/docs/forms/text-field"
      assert docs["form_wrapper"] == "https://mishka.tools/chelekom/docs/forms"
      assert docs["toggle_field"] == "https://mishka.tools/chelekom/docs/forms/toggle"
      # The one component with no page.
      assert docs["icon"] == nil
      assert Enum.count(docs, fn {_, doc} -> doc end) == 73

      assert option.note =~ "https://mishka.tools/chelekom "
    end
  end

  describe "--no-format" do
    test "by default the queued task formats what the library generated" do
      assert [{"workbench.mishka_components", ["--format" | _]}] = install().tasks
      assert Enum.any?(install().notices, &(&1 =~ "runs `mix format` over the components"))
    end

    test "the switch leaves the components as the library wrote them" do
      assert install(~w(--no-format --components card)).tasks ==
               [{"workbench.mishka_components", ["card"]}]

      refute Enum.any?(install(~w(--no-format)).notices, &(&1 =~ "mix format"))
    end
  end

  describe "--mcp" do
    defp router(igniter), do: files(igniter)["lib/test_web/router.ex"]

    test "is off by default" do
      refute install() |> apply_igniter!() |> router() =~ "MCP"
      assert {%{mcp: false}, _} = install() |> apply_igniter!() |> MishkaChelekom.state()
    end

    # WORKAROUND (mishka_chelekom 0.0.9): `mix mishka.mcp.setup` puts
    # this route inside `pipeline :browser` on phx.new's router, so the
    # cartridge writes the task's own lines at the router's end and does
    # not queue it. Remove with `mcp/2`'s compensation when the task
    # appends to the router module's block.
    # Issue: TODO — not filed yet (draft: ISSUE-mishka_chelekom-mcp-route.md).
    test "writes the library's route at the end of the router, outside every pipeline" do
      igniter = install(~w(--mcp))
      router = igniter |> apply_igniter!() |> router()

      # The in-memory project has no formatter configuration, so the
      # router's calls come back in parentheses; a project's own do not.
      assert router =~
               ~r/# MCP Server for AI tools \(development only\)\n  if Application.compile_env\(:test, :dev_routes\) do\n    forward\(?\s*"\/mcp", Anubis.Server.Transport.StreamableHTTP.Plug,\s+server: MishkaChelekom.MCP.Server\s*\)?\n  end\nend\n\z/

      [pipeline, _rest] = String.split(router, "pipeline :api", parts: 2)
      refute pipeline =~ "MCP"

      # Nothing of it is queued: the components' task alone.
      assert igniter.tasks == [{"workbench.mishka_components", ["--format"]}]
      assert Enum.any?(igniter.notices, &(&1 =~ "http://localhost:<the app's port>/mcp"))
    end

    test "says back that the route is in" do
      assert {%{mcp: true}, _} =
               install(~w(--mcp)) |> apply_igniter!() |> MishkaChelekom.state()
    end

    test "a second run adds the route to a project that has the library, and nothing else" do
      igniter = install(~w(--mcp --components card), apply_igniter!(install()))

      assert igniter |> apply_igniter!() |> router() =~ "server: MishkaChelekom.MCP.Server"
      assert igniter.tasks == []

      written = igniter |> apply_igniter!() |> files()
      assert written["lib/mix/tasks/mcp.json.ex"] =~ "defmodule Mix.Tasks.Mcp.Json"
      assert written[".gitignore"] =~ "/.mcp.json"
      refute Map.has_key?(written, "lib/test_web/components/mishka_components.ex")

      assert MishkaChelekom.adds() == [:mcp]
    end

    test "does not write it twice" do
      project = apply_igniter!(install(~w(--mcp)))
      igniter = install(~w(--mcp), project)

      assert_unchanged(igniter)
      assert Enum.any?(igniter.notices, &(&1 =~ "already forwards"))
    end
  end

  describe "mix mcp.json, the task --mcp plants" do
    @compose """
    services:
      pod:
        image: registry.k8s.io/pause:3.10
        ports:
          # Application port (host:container).
          - 4011:4000
          # Adminer port, with db_admin's adminer in.
          - 8081:8080
    """

    test "is planted with --mcp, and what it writes is ignored" do
      written = install(~w(--mcp)) |> apply_igniter!() |> files()

      assert written["lib/mix/tasks/mcp.json.ex"] == MishkaChelekom.asset("mcp.json.ex")
      assert written[".gitignore"] =~ "\n/.mcp.json\n"
      refute Map.has_key?(install() |> apply_igniter!() |> files(), "lib/mix/tasks/mcp.json.ex")
    end

    test "a task the project already has is left as it is" do
      mine = "defmodule Mix.Tasks.Mcp.Json do\nend\n"

      written =
        project()
        |> Igniter.create_new_file("lib/mix/tasks/mcp.json.ex", mine)
        |> apply_igniter!()
        |> then(&install(~w(--mcp), &1))
        |> apply_igniter!()
        |> files()

      assert written["lib/mix/tasks/mcp.json.ex"] == mine
    end

    test "the address is the port the compose publishes the endpoint's on" do
      task = task()

      assert {4011, said} = task.published(4000, @compose)
      assert said =~ "docker-compose.yml"
      assert {8081, _} = task.published(8080, @compose)

      for line <- [
            ~s(- "4011:4000"),
            "- 127.0.0.1:4011:4000",
            "- 4011:4000/tcp",
            "- '4011:4000' # app"
          ] do
        assert {4011, _} = task.published(4000, "ports:\n      #{line}\n")
      end
    end

    test "without a compose, or one that publishes no such port, it is the endpoint's own" do
      task = task()

      assert {4000, said} = task.published(4000, nil)
      assert said =~ "no docker-compose.yml"
      assert {4000, _} = task.published(4000, "services:\n  app:\n    image: x\n")
      # 14000 is not 4000, and neither is 40001.
      assert {4000, _} = task.published(4000, "ports:\n  - 5011:14000\n  - 6011:40001\n")
    end

    test "the endpoint's port is read off the app's configuration, 4000 when it says none" do
      task = task()

      env = [
        {TestWeb.Endpoint, [url: [host: "localhost"], http: [ip: {0, 0, 0, 0}, port: 4321]]},
        dev_routes: true
      ]

      assert task.endpoint_port(env) == 4321
      assert task.endpoint_port(dev_routes: true) == 4000
    end

    test "a new file has the one server; an existing one keeps its others" do
      task = task()
      url = "http://localhost:4011/mcp"

      assert {:ok, json} = task.merged(nil, url)

      assert Jason.decode!(json) == %{
               "mcpServers" => %{"mishka-chelekom" => %{"type" => "http", "url" => url}}
             }

      theirs =
        ~s({"mcpServers": {"other": {"type": "stdio", "command": "x"}, "mishka-chelekom": {"type": "http", "url": "http://localhost:1/mcp"}}, "kept": true})

      assert {:ok, json} = task.merged(theirs, url)
      config = Jason.decode!(json)

      assert config["kept"]
      assert config["mcpServers"]["other"] == %{"type" => "stdio", "command" => "x"}
      assert config["mcpServers"]["mishka-chelekom"]["url"] == url
    end

    test "a file that is no JSON object is left alone" do
      assert {:error, why} = task().merged("not json", "http://localhost:4000/mcp")
      assert why =~ "not a JSON object"
      assert {:error, _} = task().merged("[1, 2]", "http://localhost:4000/mcp")
    end
  end

  describe "the queued task's list" do
    @catalog %{
      "alert" => ["icon"],
      "button" => ["icon"],
      "carousel" => ["image", "icon"],
      "file_field" => ["spinner", "progress", "icon"],
      "icon" => [],
      "image" => [],
      "input_field" => ["icon"],
      "list" => ["icon"],
      "modal" => ["icon"],
      "navbar" => ["icon"],
      "progress" => [],
      "spinner" => [],
      "table" => [],
      "timeline" => []
    }

    test "carries the core set, which stands in for CoreComponents" do
      assert MishkaComponents.complete(["timeline"], @catalog) ==
               ~w(alert button icon input_field list modal navbar table timeline)
    end

    test "and what each component declares necessary, through the chain" do
      list = MishkaComponents.complete(["carousel", "file_field"], @catalog)

      for needed <- ~w(image spinner progress), do: assert(needed in list)
      assert list == Enum.sort(list)
    end

    test "stops on a name the catalog does not carry, before anything is written" do
      assert_raise Mix.Error, ~r/no component named kard/, fn ->
        MishkaComponents.complete(["kard", "timeline"], @catalog)
      end
    end
  end

  describe "--no-daisy" do
    test "takes the plugins out of app.css and paints the ground they painted" do
      css =
        install(~w(--no-daisy))
        |> apply_igniter!()
        |> files()
        |> Map.fetch!("assets/css/app.css")

      refute css =~ "daisyui"
      refute css =~ "daisyUI Tailwind Plugin"
      # heroicons' plugin and the variants phx.new wrote stand.
      assert css =~ ~s(@plugin "../vendor/heroicons")
      assert css =~ "@custom-variant dark"
      assert css =~ "@apply bg-white text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50;"
    end

    test "takes the dependency out, and its lock with it" do
      igniter = install(~w(--no-daisy))

      refute files(apply_igniter!(igniter))["mix.exs"] =~ ":daisyui"
      assert {"deps.unlock", ["daisyui"]} in igniter.tasks
    end

    test "rewrites the daisyUI classes of the layouts and the home page" do
      written = install(~w(--no-daisy)) |> apply_igniter!() |> files()
      layouts = written["lib/test_web/components/layouts.ex"]
      home = written["lib/test_web/controllers/page_html/home.html.heex"]

      for page <- [layouts, home] do
        refute page =~ ~r/base-(100|200|300|content)/
        refute page =~ ~r/\bbtn\b/
        refute page =~ "rounded-box"
      end

      assert layouts =~ ~s(<header class="flex w-full items-center min-h-16 py-2 px-4)
      assert layouts =~ "bg-primary-light text-white"
      assert home =~ "group-hover:bg-zinc-200 dark:group-hover:bg-zinc-700"
    end

    test "formats the pages it rewrote, then generates: in that order" do
      assert [
               {"deps.unlock", ["daisyui"]},
               {"format", pages},
               {"workbench.mishka_components", ["--format", "card"]}
             ] = install(~w(--no-daisy --components card)).tasks

      assert pages == [
               "lib/test_web/components/layouts.ex",
               "lib/test_web/controllers/page_html/home.html.heex"
             ]
    end

    # `--no-` is also how a boolean is negated on the command line; the
    # option is named whole, and read as itself, on by being given.
    test "is a switch of its own, off unless given" do
      info = MishkaChelekom.info([], nil)
      assert info.schema[:no_daisy] == :boolean
      assert info.defaults[:no_daisy] == false

      assert {[no_daisy: true], [], []} =
               OptionParser.parse(["--no-daisy"], strict: Keyword.take(info.schema, [:no_daisy]))

      assert WorkbenchIgniter.Feature.options_doc(MishkaChelekom) =~
               "* `--no-daisy` - Takes daisyUI out"
    end

    test "says back that daisyUI is out" do
      assert {%{no_daisy: true}, _} =
               install(~w(--no-daisy)) |> apply_igniter!() |> MishkaChelekom.state()
    end

    test "refuses while a package dressed in daisyUI is in, and writes nothing" do
      igniter = install(~w(--no-daisy), with_deps(project(), [:cinder]))

      assert [issue] = igniter.issues
      assert issue =~ "--no-daisy would undress"
      assert issue =~ "cinder"
      assert igniter.tasks == []
    end

    test "leaves a page the project rewrote alone" do
      plain = ~s(<div class="p-4">mine</div>\n)

      home =
        project()
        |> Igniter.create_or_update_file(
          "lib/test_web/controllers/page_html/home.html.heex",
          plain,
          &Rewrite.Source.update(&1, :content, plain)
        )
        |> apply_igniter!()
        |> then(&install(~w(--no-daisy), &1))
        |> apply_igniter!()
        |> files()
        |> Map.fetch!("lib/test_web/controllers/page_html/home.html.heex")

      assert home == plain
    end
  end

  describe "the library's documentation" do
    # Every page the form links to answers: read live, so excluded by
    # default (`mix test --only network:mishka_tools`).
    @tag network: :mishka_tools
    @tag timeout: 300_000
    test "has a page at every address a component is given" do
      pages =
        for {category, names} <- MishkaChelekom.components(),
            name <- names,
            url = MishkaChelekom.page(name, category),
            do: {name, url}

      gone =
        pages
        |> Task.async_stream(
          fn {name, url} -> {name, url, Req.get!(url, retry: false).status} end,
          max_concurrency: 8,
          timeout: 60_000
        )
        |> Enum.map(fn {:ok, answer} -> answer end)
        |> Enum.reject(fn {_, _, status} -> status == 200 end)

      assert gone == []
    end
  end

  describe "plain_classes/1" do
    test "a base colour becomes a light and a dark grey, under its variants and its opacity" do
      assert MishkaChelekom.plain_classes(~s(class="bg-base-100")) ==
               ~s(class="bg-white dark:bg-zinc-900")

      assert MishkaChelekom.plain_classes("hover:text-base-content") ==
               "hover:text-zinc-950 dark:hover:text-zinc-50"

      assert MishkaChelekom.plain_classes("fill-base-content/40") ==
               "fill-zinc-950/40 dark:fill-zinc-50/40"

      assert MishkaChelekom.plain_classes("sm:group-hover:border-base-300") ==
               "sm:group-hover:border-zinc-200 dark:sm:group-hover:border-zinc-700"
    end

    test "leaves what only looks like one" do
      for mine <- ~w(text-base my-btn btn-group navbar-brand bg-base-1000 card-title) do
        assert MishkaChelekom.plain_classes(mine) == mine
      end
    end
  end

  describe "state/1" do
    test "reads the components off the macro the library wrote, in the catalog's order" do
      macro = """
      defmodule TestWeb.Components.MishkaComponents do
        defmacro __using__(_) do
          quote do
            import TestWeb.Components.Timeline, only: [timeline: 1]
            import TestWeb.Components.InputField, only: [input: 1, error: 1]

            import TestWeb.Components.Alert,
              only: [flash: 1, alert: 1]

            import TestWeb.Components.Card
          end
        end
      end
      """

      project =
        project()
        |> Igniter.create_new_file("lib/test_web/components/mishka_components.ex", macro)
        |> apply_igniter!()

      assert {%{
                components: ~w(card timeline input_field alert),
                no_daisy: false,
                format: nil,
                mcp: false
              }, _} = MishkaChelekom.state(project)
    end

    test "answers with none before the library has written it" do
      assert {%{components: []}, _} = MishkaChelekom.state(project())
    end
  end
end
