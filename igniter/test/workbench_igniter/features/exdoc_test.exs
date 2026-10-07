defmodule WorkbenchIgniter.Features.ExdocTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  # `--coverage` lists the page `mix cover` writes, which the coverage
  # box plants with its own `--md-report`: the site is built on a project
  # that has it.
  defp with_coverage(igniter \\ phx_test_project()) do
    igniter
    # coverage's own `--md-report` builds on test_doubles: the cover task's
    # tests stand on a double of `File`.
    |> Igniter.compose_task("workbench.install.test_doubles", [])
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])
    |> apply_igniter!()
  end

  describe "mix workbench.install.exdoc" do
    test "adds the dependency and the docs configuration to mix.exs" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [
          "--project-name",
          "Lorem Ipsum",
          "--repo-url",
          "https://github.com/acme/lorem"
        ])
        |> apply_igniter!()

      mix_exs = igniter.assigns[:test_files]["mix.exs"]

      assert mix_exs =~ ~s|{:ex_doc, "~> 0.40", only: :dev, runtime: false}|
      assert mix_exs =~ ~s|name: "Lorem Ipsum"|
      assert mix_exs =~ ~s|source_url: "https://github.com/acme/lorem"|
      assert mix_exs =~ ~s|authors: ["acme"]|
      # The repository is not the website: without --homepage-url the
      # line waits commented, and the sidebar's name and logo open the
      # docs' main page, ExDoc's default.
      assert mix_exs =~ ~s|  # homepage_url: "https://example.com",\n|
      refute mix_exs =~ ~r/^\s+homepage_url:/m
      assert mix_exs =~ ~s|output: "doc"|
      assert mix_exs =~ "groups_for_modules: groups_for_modules()"
      # An image for each theme is ExDoc's own, off the URL fragment
      # (`#gh-dark-mode-only`): no script of ours goes in.
      refute mix_exs =~ "before_closing"
      refute mix_exs =~ "themedImage.js"
    end

    test "serves nothing: no route, no controller, nothing in doc/" do
      before = with_coverage()

      igniter =
        before
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # The console serves `doc/` off the workspace (console/README.md): the
      # router is phx.new's, and the site is `mix docs`'s alone to write.
      assert files["lib/test_web/router.ex"] ==
               apply_igniter!(before).assigns[:test_files]["lib/test_web/router.ex"]

      refute Enum.any?(Map.keys(files), &String.contains?(&1, "exdoc_controller"))

      # Nothing of the docs under assets/, the release build's input —
      # the Dockerfile copies it, tailwind scans it: the site's sources,
      # its scripts and its logo live under guides/.
      planted = Map.keys(files) -- Map.keys(apply_igniter!(before).assigns[:test_files])
      assert "guides/config/docs_config.js" in planted
      refute Enum.any?(planted, &String.starts_with?(&1, "assets/"))
      refute Enum.any?(Map.keys(files), &String.starts_with?(&1, "doc/"))
    end

    test "--app-logo plants the placeholder logo and names it the site's logo" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--app-logo"])

      # The logo is binary: planted verbatim by an after-apply task, not
      # through the rewrite pipeline (which would normalize its bytes).
      # Asserted before the apply, which consumes the task list.
      assert_has_task(igniter, "workbench.plant_asset", [
        "exdoc",
        "images/app-logo.png",
        "guides/images/app-logo.png"
      ])

      assert apply_igniter!(igniter).assigns[:test_files]["mix.exs"] =~
               ~s|logo: "guides/images/app-logo.png"|
    end

    test "--homepage-url is where the sidebar's name and logo link" do
      mix_exs =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [
          "--homepage-url",
          "https://lorem.example.com"
        ])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert mix_exs =~ ~r/^\s+homepage_url: "https:\/\/lorem.example.com",$/m
      refute mix_exs =~ ~s|# homepage_url:|
      # The logo is another option's.
      refute mix_exs =~ "logo:"
    end

    test "writes the site where --output says, and says it back; doc unasked" do
      state = fn argv ->
        igniter =
          phx_test_project()
          |> Igniter.compose_task("workbench.install.exdoc", argv)
          |> apply_igniter!()

        {%{output: dir}, _} = WorkbenchIgniter.Features.Exdoc.state(igniter)
        {dir, igniter.assigns[:test_files]["mix.exs"]}
      end

      assert {"doc", mix_exs} = state.([])
      assert mix_exs =~ ~s|output: "doc"|

      # Under priv/static the app serves the site itself; the trailing
      # slash is trimmed, since ExDoc takes the directory bare.
      assert {"priv/static/doc", mix_exs} = state.(["--output", "priv/static/doc/"])
      assert mix_exs =~ ~s|output: "priv/static/doc"|
    end

    test "an output that climbs out of the project, or is absolute, is refused" do
      for bad <- ["../elsewhere", "/tmp/doc", "doc/../../x"] do
        igniter =
          phx_test_project()
          |> Igniter.compose_task("workbench.install.exdoc", ["--output", bad])

        assert_has_issue(igniter, &(&1 =~ "--output takes a directory inside the project"))
        refute Igniter.exists?(igniter, "guides/config/docs_config.js")
      end
    end

    test "says back the website given, and none for the placeholder" do
      state = fn argv ->
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", argv)
        |> apply_igniter!()
        |> WorkbenchIgniter.Features.Exdoc.state()
        |> elem(0)
        |> Map.get(:homepage_url)
      end

      assert state.(["--homepage-url", "https://lorem.example.com"]) ==
               "https://lorem.example.com"

      assert state.([]) == nil
    end

    test "plants the documentation assets, and no logo unless asked" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])

      # ExDoc refuses a `logo:` whose file is missing: neither goes in.
      refute Enum.any?(igniter.tasks, &match?({"workbench.plant_asset", _}, &1))

      igniter = apply_igniter!(igniter)
      files = igniter.assigns[:test_files]
      refute files["mix.exs"] =~ "logo:"

      assert Map.has_key?(files, "guides/config/docs_config.js")
      refute Map.has_key?(files, "guides/js/themedImage.js")
      # The workbench tool page is not part of the project docs.
      refute Map.has_key?(files, "guides/workbench.md")
      # The database page is dbschema's, listed here when it is in.
      refute Map.has_key?(files, "guides/database.md")
      # The token page went with --auth0 (v0.2.0): it needs the app's origin.
      refute Map.has_key?(files, "guides/token.md")
      refute Map.has_key?(files, "guides/js/token.js")
      refute files["mix.exs"] =~ "auth0"
    end

    test "--coverage needs the box that writes the report, with its --md-report" do
      refused =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])

      assert_has_issue(refused, &(&1 =~ "--coverage builds on coverage with md_report"))
      refute Igniter.exists?(refused, "guides/config/docs_config.js")

      # In without it, the box is there and the task is not: still
      # refused, and the line to run says what to add.
      half =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])

      assert_has_issue(half, &(&1 =~ "./wb.sh add coverage --md-report"))
    end

    test "--coverage adds the report page, and the report beside it" do
      igniter =
        with_coverage()
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # The TESTING.md placeholder lands at the project
      # root, where `mix cover` regenerates them, and are referenced from
      # the docs extras.
      assert files["TESTING.md"] =~ "mix cover"
      refute Map.has_key?(files, "COVERAGE.md")
      refute Map.has_key?(files, "guides/testing.md")
      assert files["mix.exs"] =~ ~s|{"TESTING.md", [title: "Test Suite Report"]}|
      refute files["mix.exs"] =~ "COVERAGE.md"
      # ExCoveralls' HTML is copied into the site's root, beside the page
      # that links it.
      assert files["mix.exs"] =~ ~s|"cover" => "/"|
    end

    # The insert writes files and never runs mix docs: the site is
    # built from its door in the console, or with `./wb.sh mix docs`.
    test "the insert queues no run of its own" do
      igniter = phx_test_project() |> Igniter.compose_task("workbench.install.exdoc", [])

      refute Enum.any?(igniter.tasks, &match?({"docs", _}, &1))
    end

    # The report is `mix cover`'s to write. The box that plants that
    # task plants a page until it runs, so the normal order lists it
    # live; a project that took the page away gets the slot instead, and
    # `mix docs` builds either way.
    test "--coverage lists the report when it is there, and waits commented when it is not" do
      live =
        with_coverage()
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert live =~ ~s|{"TESTING.md", [title: "Test Suite Report"]}|
      refute live =~ ~s|# {"TESTING.md"|

      slot =
        with_coverage()
        |> Igniter.rm("TESTING.md")
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert slot =~ ~s|    # {"TESTING.md", [title: "Test Suite Report"]}\n|
      assert slot =~ ~s|      # "TESTING.md"\n|
      refute slot =~ ~r/^\s*\{"TESTING\.md"/m
      assert {:ok, _} = Code.string_to_quoted(slot)
      # The report's own directory is copied either way: ExDoc skips an
      # asset directory that is not there.
      assert slot =~ ~s|"cover" => "/"|
    end

    test "without --coverage, no report page and nothing copied from cover/" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files])

      refute Map.has_key?(files, "TESTING.md")
      refute files["mix.exs"] =~ "TESTING.md"
      refute files["mix.exs"] =~ ~s|"cover" => "/"|
    end

    # ExDoc draws no group without pages; the empty one is where a
    # changelog opened later is listed.
    test "with no README yet the two lines wait commented, and a README written later takes the slot" do
      slot =
        phx_test_project()
        |> Igniter.rm("README.md")
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      mix_exs = slot.assigns[:test_files]["mix.exs"]

      # `mix docs` stops on an extra whose file is missing, and on a
      # `main:` that names no page: the slot carries neither.
      assert mix_exs =~ ~s|    # {"README.md", [title: "Overview"]}\n|
      assert mix_exs =~ ~s|      # "README.md"\n|
      refute mix_exs =~ ~r/^\s*\{"README\.md"/m
      refute mix_exs =~ "main:"
      assert {:ok, _} = Code.string_to_quoted(mix_exs)

      # The slot taken: the group holds the page and nothing else.
      {true, opened} =
        slot
        |> Igniter.create_new_file("README.md", "# Lorem\n")
        |> WorkbenchIgniter.Features.Exdoc.uncomment_page("README.md", "Overview", :Project)

      mix_exs = opened |> apply_igniter!() |> then(& &1.assigns[:test_files]["mix.exs"])
      assert [_, project] = Regex.run(~r/Project: \[(.*?)\]/s, mix_exs)
      assert String.trim(project) == ~s|"README.md"|
      assert {:ok, _} = Code.string_to_quoted(mix_exs)
    end

    test "--changelog needs the changelog box, and lists the page with it in" do
      # Asked for without the box that writes the file: refused, naming
      # it, and nothing is written.
      refused =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--changelog"])

      assert_has_issue(refused, &(&1 =~ "--changelog builds on changelog"))
      refute Igniter.exists?(refused, "guides/config/docs_config.js")

      # With it in, the page is listed live, beside the README.
      mix_exs =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.exdoc", ["--changelog"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert mix_exs =~ ~s|{"CHANGELOG.md", [title: "Changelog"]}|
      assert [_, project] = Regex.run(~r/Project: \[(.*?)\]/s, mix_exs)
      assert project =~ ~s|"README.md"| and project =~ ~s|"CHANGELOG.md"|
      assert {:ok, _} = Code.string_to_quoted(mix_exs)
    end

    test "unasked, the site lists no changelog: the box that opens one lists its own page" do
      mix_exs =
        phx_test_project()
        |> Igniter.create_new_file("CHANGELOG.md", "# Changelog\n")
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      refute mix_exs =~ "CHANGELOG.md"
    end

    test "says back what the site lists: the changelog live, and the README's slot as no listing" do
      state = fn igniter, argv ->
        igniter
        |> Igniter.compose_task("workbench.install.exdoc", argv)
        |> apply_igniter!()
        |> WorkbenchIgniter.Features.Exdoc.state()
        |> elem(0)
      end

      with_box =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert state.(with_box, ["--changelog"]).changelog == true
      assert state.(phx_test_project(), []).changelog == false

      assert state.(phx_test_project(), []).readme == true
      # The slot is no listing: the site has no such page yet.
      assert state.(Igniter.rm(phx_test_project(), "README.md"), []).readme == false

      # The report page, both ways: the box that writes it is in, and
      # the site was told to list it or was not.
      with_report =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.test_doubles", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])
        |> apply_igniter!()

      assert state.(with_report, ["--coverage"]).coverage == true
      assert state.(with_report, []).coverage == false

      # The logo and the name, which the mark alone does not say.
      assert state.(phx_test_project(), ["--app-logo"]).app_logo == true
      assert state.(phx_test_project(), []).app_logo == false
      assert state.(phx_test_project(), ["--project-name", "Lorem"]).project_name == "Lorem"
      assert state.(phx_test_project(), []).project_name == "Test"
    end

    test "the README opens the site, unless --no-readme leaves it out" do
      mix_exs = fn argv ->
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", argv)
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])
      end

      with_readme = mix_exs.([])
      assert with_readme =~ ~s|{"README.md", [title: "Overview"]}|
      assert with_readme =~ ~s|main: "readme"|

      without = mix_exs.(["--no-readme"])
      refute without =~ "README.md"
      refute without =~ "main:"
    end

    test "the module groups follow the project: layers on Phoenix, ash on Ash" do
      mix_exs = fn igniter ->
        igniter
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])
      end

      phoenix = mix_exs.(phx_test_project())
      assert phoenix =~ "exdoc --module-groups layers"
      assert phoenix =~ "defp groups_for_modules do"
      # The web layer and its helpers, once.
      assert phoenix =~
               ~s|"Live views": [&behaves?(&1, [Phoenix.LiveView, Phoenix.LiveComponent])]|

      assert phoenix =~ ~s|&in_dir?(&1, "lib/test_web/components/")|
      assert length(String.split(phoenix, "defp behaves?(")) == 2

      ash =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ash, "~> 3.0"})
        |> apply_igniter!()
        |> mix_exs.()

      assert ash =~ "exdoc --module-groups ash"
      assert ash =~ "Domains: [&behaves?(&1, [Ash.Domain])]"
    end

    test "--module-groups asked for wins over what the project is" do
      on_ash =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ash, "~> 3.0"})
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.exdoc", ["--module-groups", "layers"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert on_ash =~ "exdoc --module-groups layers"
      refute on_ash =~ "Ash.Domain"

      on_phoenix =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--module-groups", "ash"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert on_phoenix =~ "exdoc --module-groups ash"
    end

    test "--module-groups contexts reads lib/<app>/ when the docs are built" do
      mix_exs =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--module-groups", "contexts"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert mix_exs =~ "exdoc --module-groups contexts"
      assert mix_exs =~ ~s|dir = "lib/test"|
      assert mix_exs =~ "for {:ok, entries} <- [File.ls(dir)]"
    end

    test "--module-groups none leaves ExDoc's own list" do
      mix_exs =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--module-groups", "none"])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      refute mix_exs =~ "groups_for_modules"
      refute mix_exs =~ "behaves?"
    end

    test "an unknown preset is refused, naming the four" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--module-groups", "flat"])

      assert [issue] = igniter.issues
      assert issue =~ ~s|Unknown --module-groups "flat"|
      assert issue =~ "layers, ash, contexts, none"
    end

    test "the site's name: the flag, else mix.exs's name, else the app's name in words" do
      name = fn igniter, argv ->
        igniter
        |> Igniter.compose_task("workbench.install.exdoc", argv)
        |> apply_igniter!()
        |> then(&Regex.run(~r/^      name: (.*),$/m, &1.assigns[:test_files]["mix.exs"]))
        |> List.last()
      end

      assert name.(phx_test_project(app_name: :lorem_ipsum_3), []) == ~s|"Lorem Ipsum 3"|

      named =
        phx_test_project()
        |> Igniter.Project.MixProject.update(:project, [:name], fn _ ->
          {:ok, {:code, ~s|"ACME Portal"|}}
        end)
        |> apply_igniter!()

      assert name.(named, []) == ~s|"ACME Portal"|
      assert name.(named, ["--project-name", "Other"]) == ~s|"Other"|
    end

    test "the repository: the flag, else mix.exs's source_url, else a placeholder" do
      source_url = fn igniter, argv ->
        igniter
        |> Igniter.compose_task("workbench.install.exdoc", argv)
        |> apply_igniter!()
        |> then(&Regex.run(~r/^      source_url: (.*),$/m, &1.assigns[:test_files]["mix.exs"]))
        |> List.last()
      end

      # Under Igniter.Test the git remote is not read (it would be the
      # workbench's): nothing found, so the placeholder, commented out —
      # live, every source link would 404 — and no authors, whose owner
      # would be the placeholder's.
      found_nothing =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files]["mix.exs"])

      assert found_nothing =~ ~s|      # source_url: "https://github.com/user/repo",\n|
      refute found_nothing =~ ~r/^\s+source_url:/m
      refute found_nothing =~ "authors:"

      # Asked for, it is written live, even the placeholder's own URL.
      assert source_url.(phx_test_project(), ["--repo-url", "https://github.com/user/repo"]) ==
               ~s|"https://github.com/user/repo"|

      kept =
        phx_test_project()
        |> Igniter.Project.MixProject.update(:project, [:source_url], fn _ ->
          {:ok, {:code, ~s|"https://gitlab.com/acme/portal"|}}
        end)
        |> apply_igniter!()

      assert source_url.(kept, []) == ~s|"https://gitlab.com/acme/portal"|
      assert source_url.(kept, ["--repo-url", "https://x.test/a/b"]) == ~s|"https://x.test/a/b"|
    end

    test "reads a project from v0.1.0, which served the site from a controller, as exdoc" do
      igniter =
        phx_test_project()
        |> Igniter.create_new_file("assets/exdoc/config/docs_config.js", "")
        |> Igniter.create_new_file(
          "lib/test_web/controllers/exdoc_controller.ex",
          "defmodule TestWeb.ExDocController do\nend\n"
        )
        |> apply_igniter!()

      assert {true, _} = WorkbenchIgniter.Features.Exdoc.installed?(igniter)
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.exdoc", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.exdoc", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "composition through chiefs_setup" do
    test "the collection composes the installer with its recipe argv" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.chiefs_setup", [])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # The recipe's --coverage: the report page is one of the site's extras.
      assert files["mix.exs"] =~ ~s|{"TESTING.md", [title: "Test Suite Report"]}|
    end
  end
end
