defmodule WorkbenchIgniter.Features.BaseCartridgesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features

  defp project(extra), do: WorkbenchIgniter.TestProject.new(extra)

  defp files(igniter), do: apply_igniter!(igniter).assigns[:test_files]

  test "the marks: out on the flag, in by default" do
    for {feature, flag} <- [
          {Features.Esbuild, "--no-esbuild"},
          {Features.Tailwind, "--no-tailwind"},
          {Features.Html, "--no-html"},
          {Features.Live, "--no-live"},
          {Features.Dashboard, "--no-dashboard"}
        ] do
      assert {false, _} = feature.installed?(project([flag])),
             "#{flag} should leave #{feature.name()} out"

      assert {true, _} = feature.installed?(project([])),
             "#{feature.name()} should be in by default"
    end
  end

  test "the first bundler brings the Dockerfile's assets steps, as phx.gen.release would have" do
    # Born without assets/, the Dockerfile has no assets steps: the
    # generator decided off the directory (test_01, 2026-09-17).
    bare = project(~w(--no-html --no-esbuild --no-tailwind))
    refute files(bare)["Dockerfile"] =~ "assets"

    igniter = bare |> Igniter.compose_task("workbench.install.esbuild", [])
    assert igniter.issues == []

    igniter
    |> assert_has_patch("Dockerfile", """
    + | RUN mix assets.setup
    """)
    |> assert_has_patch("Dockerfile", """
    + | RUN mix assets.deploy
    """)

    # The second bundler finds them there.
    both = igniter |> apply_igniter!() |> Igniter.compose_task("workbench.install.tailwind", [])
    assert both.issues == []
    assert_unchanged(both, "Dockerfile")

    # A Dockerfile that is not phx.gen.release's is left alone.
    own =
      WorkbenchIgniter.TestProject.new(~w(--no-html --no-esbuild --no-tailwind), %{
        "Dockerfile" => "FROM elixir:1.19\n"
      })
      |> Igniter.compose_task("workbench.install.esbuild", [])

    assert own.issues == []
    assert_unchanged(own, "Dockerfile")
  end

  test "esbuild: the dependency, its config and the watcher" do
    igniter = project(~w(--no-esbuild)) |> Igniter.compose_task("workbench.install.esbuild", [])
    assert igniter.issues == []
    files = files(igniter)
    assert files["mix.exs"] =~ ":esbuild"
    assert files["config/config.exs"] =~ "config :esbuild"
    assert files["config/dev.exs"] =~ "esbuild:"
  end

  test "tailwind: the dependency, its config and the watcher" do
    igniter = project(~w(--no-tailwind)) |> Igniter.compose_task("workbench.install.tailwind", [])
    assert igniter.issues == []
    files = files(igniter)
    assert files["mix.exs"] =~ ":tailwind"
    assert files["config/config.exs"] =~ "config :tailwind"
    assert files["config/dev.exs"] =~ "tailwind:"
  end

  test "html: Phoenix.HTML, the browser pipeline, the components and the page" do
    igniter = project(~w(--no-html)) |> Igniter.compose_task("workbench.install.html", [])
    assert igniter.issues == []
    files = files(igniter)
    assert files["mix.exs"] =~ ":phoenix_html"
    assert files["lib/test_web/router.ex"] =~ "pipeline :browser"
    assert files["lib/test_web/components/core_components.ex"]
    assert files["lib/test_web/controllers/page_controller.ex"]
    # html alone: phx.new generates live only on top of it, on request
    refute files["config/config.exs"] =~ "config :phoenix_live_view"
  end

  test "live: its configuration, the socket in app.js and the JS commands" do
    igniter = project(~w(--no-live)) |> Igniter.compose_task("workbench.install.live", [])
    assert igniter.issues == []
    files = files(igniter)
    assert files["config/config.exs"] =~ "config :phoenix_live_view"
    assert files["assets/js/app.js"] =~ ~r/^const liveSocket = new LiveSocket/m
    assert files["lib/test_web/components/core_components.ex"] =~ "alias Phoenix.LiveView.JS"
  end

  test "live builds on html: refuses on a --no-html project, naming it" do
    igniter = project(~w(--no-html)) |> Igniter.compose_task("workbench.install.live", [])
    assert [issue] = igniter.issues
    assert issue =~ "live builds on html"
    assert issue =~ "./wb.sh add html"
    assert Features.entry(Features.Live).requires == ["html"]
  end

  test "dashboard: the dependency, the route, and the socket it rides on" do
    igniter =
      project(~w(--no-dashboard --no-live))
      |> Igniter.compose_task("workbench.install.dashboard", [])

    assert igniter.issues == []
    files = files(igniter)
    assert files["mix.exs"] =~ ":phoenix_live_dashboard"
    assert files["lib/test_web/router.ex"] =~ ~s|live_dashboard "/dashboard"|
    assert files["lib/test_web/endpoint.ex"] =~ ~r/^  socket "\/live"/m
  end

  # A capability that appends at the end of a file an earlier insert
  # wrote (ecto on gettext's errors.pot; live on AGENTS.md and app.js
  # after html and esbuild): the trailing newline Igniter writes and
  # phx.new's templates do not must not read as the project's edit.
  test "ecto after gettext: the .pot gains the Ecto messages, no conflict" do
    igniter =
      WorkbenchIgniter.TestProject.new(~w(--no-gettext --no-ecto), %{".env" => "PORT=\"4000\"\n"})
      |> Igniter.compose_task("workbench.install.gettext", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.ecto", [])

    assert igniter.issues == []
    files = files(igniter)
    assert files["priv/gettext/errors.pot"] =~ "From Ecto.Changeset.cast/4"
    assert files["priv/gettext/en/LC_MESSAGES/errors.po"] =~ "From Ecto.Changeset.cast/4"
  end

  test "live after html and esbuild were inserted: AGENTS.md and app.js, no conflict" do
    igniter =
      project(~w(--no-html --no-esbuild))
      |> Igniter.compose_task("workbench.install.html", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.esbuild", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.live", [])

    assert igniter.issues == []
    files = files(igniter)
    assert files["AGENTS.md"] =~ "phoenix:liveview-start"
    assert files["assets/js/app.js"] =~ ~r/^const liveSocket = new LiveSocket/m
    refute files["assets/js/app.js"] =~ "[role=alert][data-flash]"
  end

  test "a project generated with --no-agents-md does not get an AGENTS.md" do
    igniter =
      WorkbenchIgniter.TestProject.new(~w(--no-ecto --no-agents-md), %{
        ".env" => "PORT=\"4000\"\n"
      })
      |> Igniter.compose_task("workbench.install.ecto", [])

    assert igniter.issues == []
    refute Map.has_key?(files(igniter), "AGENTS.md")
  end

  test "esbuild and tailwind take phx.new's static placeholders away, untouched ones only" do
    # html on an API-only project brings the placeholders; esbuild
    # replaces app.js's, tailwind app.css's and default.css.
    with_html =
      project(~w(--no-html --no-esbuild --no-tailwind))
      |> Igniter.compose_task("workbench.install.html", [])
      |> apply_igniter!()

    assert files(with_html)["priv/static/assets/js/app.js"] =~ "copy the following scripts"

    after_esbuild = with_html |> Igniter.compose_task("workbench.install.esbuild", [])
    assert after_esbuild.issues == []
    refute Map.has_key?(files(after_esbuild), "priv/static/assets/js/app.js")

    after_tailwind = with_html |> Igniter.compose_task("workbench.install.tailwind", [])
    refute Map.has_key?(files(after_tailwind), "priv/static/assets/css/app.css")
    refute Map.has_key?(files(after_tailwind), "priv/static/assets/default.css")

    # A placeholder the project rewrote is the project's, and stays.
    edited =
      with_html
      |> Igniter.update_file(
        "priv/static/assets/js/app.js",
        &Rewrite.Source.update(&1, :content, fn _ -> "console.log('mine')\n" end)
      )
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.esbuild", [])

    assert files(edited)["priv/static/assets/js/app.js"] == "console.log('mine')\n"
  end

  test "tailwind without html and live without esbuild say what the build lacks" do
    tailwind =
      project(~w(--no-html --no-esbuild --no-tailwind))
      |> Igniter.compose_task("workbench.install.tailwind", [])

    assert tailwind.issues == []
    assert Enum.any?(tailwind.notices, &(&1 =~ "phoenix-colocated"))

    live =
      project(~w(--no-live --no-esbuild)) |> Igniter.compose_task("workbench.install.live", [])

    assert live.issues == []
    assert Enum.any?(live.notices, &(&1 =~ "assets/js/app.js"))

    quiet = project(~w(--no-live)) |> Igniter.compose_task("workbench.install.live", [])
    refute Enum.any?(quiet.notices, &(&1 =~ "assets/js/app.js"))
  end

  test "refuses a project generated by another phx.new, writing nothing" do
    igniter =
      project(~w(--no-dashboard))
      |> Igniter.update_file("mix.exs", fn source ->
        Rewrite.Source.update(
          source,
          :content,
          &Regex.replace(~r/\{:phoenix, "~> [\d.]+"\}/, &1, ~s|{:phoenix, "~> 9.9.9"}|)
        )
      end)
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.dashboard", [])

    assert [issue] = igniter.issues
    assert issue =~ "generated by phx.new 9.9.9"
    assert_unchanged(igniter)
  end

  test "each is a no-op with a notice when in" do
    for task <- ~w(esbuild tailwind html live dashboard) do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.#{task}", [])
      |> assert_unchanged()
    end
  end
end
