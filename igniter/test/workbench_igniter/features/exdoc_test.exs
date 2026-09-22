defmodule WorkbenchIgniter.Features.ExdocTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

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

      assert mix_exs =~ ~s|{:ex_doc, "~> 0.38", only: :dev, runtime: false}|
      assert mix_exs =~ ~s|name: "Lorem Ipsum"|
      assert mix_exs =~ ~s|source_url: "https://github.com/acme/lorem"|
      assert mix_exs =~ ~s|authors: ["acme"]|
      # The repository is not the website: without --homepage-url the
      # sidebar's name and logo open the docs' main page, ExDoc's default.
      refute mix_exs =~ "homepage_url"
      assert mix_exs =~ ~s|output: "doc"|
      assert mix_exs =~ "groups_for_modules: groups_for_modules()"
      assert mix_exs =~ "before_closing_body_tag: &before_closing_body_tag/1"
      assert mix_exs =~ ~s|defp before_closing_body_tag(:html) do|
      assert mix_exs =~ "themedImage.js"
    end

    test "serves nothing: no route, no controller, nothing in doc/" do
      before = phx_test_project()

      igniter =
        before
        |> Igniter.compose_task("workbench.install.exdoc", ["--coverage"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # The console serves `doc/` off the workspace (console/PLAN.md): the
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

      assert mix_exs =~ ~s|homepage_url: "https://lorem.example.com"|
      # The logo is another option's.
      refute mix_exs =~ "logo:"
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
      assert Map.has_key?(files, "guides/js/themedImage.js")
      # The workbench tool page is not part of the project docs.
      refute Map.has_key?(files, "guides/workbench.md")
      # Ecto default: database placeholder and db diagram.
      assert files["guides/database.md"] =~ "# Database"
      # The token page went with --auth0 (v0.2.0): it needs the app's origin.
      refute Map.has_key?(files, "guides/token.md")
      refute Map.has_key?(files, "guides/js/token.js")
      refute files["mix.exs"] =~ "auth0"
    end

    test "--coverage adds the report page, and the report beside it" do
      igniter =
        phx_test_project()
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

    test "lists the changelog when the project keeps one, and only then" do
      without =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      # `mix docs` stops on an extra whose file is missing.
      refute without.assigns[:test_files]["mix.exs"] =~ "CHANGELOG.md"

      with_one =
        phx_test_project()
        |> Igniter.create_new_file("CHANGELOG.md", "# Changelog\n")
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      mix_exs = with_one.assigns[:test_files]["mix.exs"]
      assert mix_exs =~ ~s|{"CHANGELOG.md", [title: "Changelog"]}|
      assert [_, project] = Regex.run(~r/Project: \[(.*?)\]/s, mix_exs)
      assert project =~ ~s|"README.md"| and project =~ ~s|"CHANGELOG.md"|
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
