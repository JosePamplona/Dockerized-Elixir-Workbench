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
      assert mix_exs =~ ~s|homepage_url: "https://github.com/acme/lorem"|
      assert mix_exs =~ ~s|output: "doc"|
      assert mix_exs =~ "Contexts: ~r/^Test\\."
      assert mix_exs =~ "before_closing_body_tag: &before_closing_body_tag/1"
      assert mix_exs =~ ~s|defp before_closing_body_tag(:html) do|
      assert mix_exs =~ "themedImage.js"
    end

    test "creates the controller, tests, router pipeline and dev routes" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]
      router = files["lib/test_web/router.ex"]

      assert files["lib/test_web/controllers/exdoc_controller.ex"] =~
               "defmodule TestWeb.ExDocController do"

      assert files["test/test_web/controllers/exdoc_controller_test.exs"] =~
               "defmodule TestWeb.ExDocControllerTest do"

      assert router =~ "pipeline :exdoc do"
      # The standard `doc/` output dir, served relative to the VM cwd.
      assert router =~ ~s|from: "doc"|
      assert router =~ ~s|get("/docs/", ExDocController, :index)|
      assert router =~ ~s|get("/docs/*path", ExDocController, :handle)|
      # Without --coveralls there is no cover route or action.
      refute router =~ ":cover"
      refute files["lib/test_web/controllers/exdoc_controller.ex"] =~ "def cover"
    end

    test "plants the documentation assets" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])

      # The logo is binary: planted verbatim by an after-apply task, not
      # through the rewrite pipeline (which would normalize its bytes).
      # Asserted before the apply, which consumes the task list.
      assert_has_task(igniter, "workbench.plant_asset", [
        "exdoc",
        "images/app-logo.png",
        "assets/exdoc/images/app-logo.png"
      ])

      igniter = apply_igniter!(igniter)
      files = igniter.assigns[:test_files]

      assert Map.has_key?(files, "assets/exdoc/config/docs_config.js")
      assert Map.has_key?(files, "assets/exdoc/js/themedImage.js")
      # The workbench tool page is not part of the project docs.
      refute Map.has_key?(files, "assets/exdoc/workbench.md")
      # Ecto default: database placeholder and db diagram.
      assert files["assets/exdoc/database.md"] =~ "# Database"
      # No auth0: no token page or script.
      refute Map.has_key?(files, "assets/exdoc/token.md")
      refute Map.has_key?(files, "assets/exdoc/js/token.js")
    end

    test "--coveralls adds the cover route, action, page and dummy" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--coveralls"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["lib/test_web/router.ex"] =~
               ~s|get("/docs/cover", ExDocController, :cover)|

      assert files["lib/test_web/controllers/exdoc_controller.ex"] =~ "def cover"
      # The TESTING.md placeholder lands at the project
      # root, where `mix cover` regenerates them, and are referenced from
      # the docs extras.
      assert files["TESTING.md"] =~ "mix cover"
      refute Map.has_key?(files, "COVERAGE.md")
      refute Map.has_key?(files, "assets/exdoc/testing.md")
      assert files["mix.exs"] =~ ~s|{"TESTING.md", [title: "Test Suite Report"]}|
      refute files["mix.exs"] =~ "COVERAGE.md"
      assert Map.has_key?(files, "doc/excoveralls.html")
      assert files["mix.exs"] =~ ~s|"cover" => "/"|
    end

    test "--auth0 adds the token page and scripts" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--auth0"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert Map.has_key?(files, "assets/exdoc/token.md")
      assert Map.has_key?(files, "assets/exdoc/js/token.js")
      assert files["mix.exs"] =~ "auth0-spa-js"
    end

    test "seeds dummy pages in the doc output dir" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", ["--project-name", "Demo"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["doc/index.html"] =~ "<title>Demo v0.0.0 — Documentation</title>"
      assert files["doc/404.html"] =~ "<title>404 — Demo v0.0.0</title>"
    end

    test "plants into the app-name directories when the name carries digits" do
      igniter =
        phx_test_project(app_name: :test_3)
        |> Igniter.compose_task("workbench.install.exdoc", ["--project-name", "Demo"])
        |> apply_igniter!()

      files = Map.keys(igniter.assigns[:test_files])

      # Macro.underscore(Test3Web) would plant into a parallel "test3_web"
      # tree, diverging from the phx.new app-name directories. (The igniter
      # phx test scaffold itself uses the module-derived layout, so only
      # the files this feature plants are asserted.)
      assert "lib/test_3_web/controllers/exdoc_controller.ex" in files
      assert "test/test_3_web/controllers/exdoc_controller_test.exs" in files
      refute "lib/test3_web/controllers/exdoc_controller.ex" in files
    end

    test "--version drives the placeholder titles" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [
          "--project-name",
          "Demo",
          "--version",
          "1.2.3"
        ])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["doc/index.html"] =~ "<title>Demo v1.2.3 — Documentation</title>"
      assert files["doc/404.html"] =~ "<title>404 — Demo v1.2.3</title>"

      # The generated test follows the project version instead of pinning it.
      controller_test = files["test/test_web/controllers/exdoc_controller_test.exs"]
      assert controller_test =~ "@version Mix.Project.config()[:version]"
      assert controller_test =~ ~s|"<title>Demo v\#{@version} — Documentation"|
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

      # The recipe's --coveralls: the docs controller serves the report.
      assert files["lib/test_web/controllers/exdoc_controller.ex"] =~ "def cover"
    end
  end
end
