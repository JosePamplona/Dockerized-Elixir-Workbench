defmodule WorkbenchIgniter.RouterFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import WorkbenchIgniter.Grown, only: [born: 1, add: 2]

  alias WorkbenchIgniter.PhxDelta
  alias WorkbenchIgniter.RouterFile

  @router "lib/test_web/router.ex"

  # The four capabilities that write into the router, and every shape
  # phx.new makes of it: live only with html.
  @capabilities ~w(html live dashboard mailer)

  defp router(on) do
    off = for c <- @capabilities, c not in on, do: "--no-#{c}"

    PhxDelta.generate(
      ~w(--app test --module Test --database postgres --adapter bandit) ++ off,
      WorkbenchIgniter.TestProject.docker()
    )
    |> Map.fetch!(@router)
  end

  defp shapes do
    for html <- [true, false],
        live <- if(html, do: [true, false], else: [false]),
        dashboard <- [true, false],
        mailer <- [true, false] do
      for {c, true} <- [html: html, live: live, dashboard: dashboard, mailer: mailer],
          do: to_string(c)
    end
  end

  defp normal(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp edit(igniter, fun) do
    Igniter.assign(igniter, :test_files, Map.update!(igniter.assigns[:test_files], @router, fun))
  end

  defp routed(igniter),
    do: igniter.rewrite |> Rewrite.source!(@router) |> Rewrite.Source.get(:content)

  describe "the operations say every change phx.new makes to the router" do
    # Not a fallback, anywhere: for each shape and each capability it
    # lacks, the operations read off the two generations turn base into
    # theirs — the check merge/3 makes before applying anything.
    test "from every shape, each capability it lacks" do
      for shape <- shapes(), c <- @capabilities, c not in shape, c != "live" or "html" in shape do
        base = router(shape)
        theirs = router([c | shape])

        assert {:ok, merged, []} = RouterFile.merge(base, base, theirs),
               "#{c} over #{inspect(shape)} fell back to the text merge"

        assert normal(merged) == normal(theirs)
      end
    end
  end

  describe "a router the project has used" do
    test "html over an API keeps the project's scope \"/api\" and adds the page beside it" do
      {:ok, grown} =
        born(~w(mailer gettext ecto dashboard))
        |> edit(
          &String.replace(
            &1,
            "pipe_through :api\n",
            ~s(pipe_through :api\n\n    get "/status", StatusController, :show\n),
            global: false
          )
        )
        |> add("html")

      router = routed(grown)
      assert router =~ ~s(pipeline :browser do)
      assert router =~ ~s(get "/", PageController, :home)

      assert router =~
               ~s(scope "/api", TestWeb do\n    pipe_through :api\n\n    get "/status", StatusController, :show\n  end)

      assert router =~ ~s(scope "/dev" do\n      pipe_through :browser)
    end

    test "html says in a notice that the project's scope \"/api\" stays" do
      igniter =
        born(~w(mailer gettext ecto dashboard))
        |> edit(
          &String.replace(
            &1,
            "pipe_through :api\n",
            ~s(pipe_through :api\n    get "/status", StatusController, :show\n),
            global: false
          )
        )
        |> Igniter.compose_task("workbench.install.html", ["--no-live"])

      assert igniter.issues == []

      assert Enum.any?(
               igniter.notices,
               &(&1 =~ ~s(scope "/api", TestWeb is the project's own now))
             )
    end

    test "dashboard and mailer open the dev block at the end, after a scope the project appended" do
      appended = fn r ->
        String.replace_suffix(
          String.trim_trailing(r),
          "end",
          ~s(\n  scope "/webhooks", TestWeb do\n    pipe_through :api\n    post "/stripe", StripeController, :create\n  end\nend\n)
        )
      end

      for cartridge <- ~w(dashboard mailer) do
        {:ok, grown} =
          born(~w(gettext ecto esbuild tailwind html)) |> edit(appended) |> add(cartridge)

        router = routed(grown)

        assert router =~ ~r/scope "\/webhooks".*if Application.compile_env/s
        # phx.new's closing comment, which the project's scope now
        # follows, is not brought a second time with the dev block.
        assert length(String.split(router, "# Other scopes may use custom stacks.")) == 2
      end
    end

    test "mailer adds its route after one the project put in /dev" do
      {:ok, grown} =
        born(~w(gettext ecto esbuild tailwind html dashboard))
        |> edit(
          &String.replace(
            &1,
            "live_dashboard \"/dashboard\", metrics: TestWeb.Telemetry\n",
            "live_dashboard \"/dashboard\", metrics: TestWeb.Telemetry\n      get \"/seed\", DevController, :seed\n"
          )
        )
        |> add("mailer")

      assert routed(grown) =~
               ~s(live_dashboard "/dashboard", metrics: TestWeb.Telemetry\n      get "/seed", DevController, :seed\n      forward "/mailbox", Plug.Swoosh.MailboxPreview)

      assert routed(grown) =~ "# Enable LiveDashboard and Swoosh mailbox preview in development"
    end

    test "dashboard puts its route before one the project put in /dev" do
      {:ok, grown} =
        born(~w(mailer gettext ecto esbuild tailwind html))
        |> edit(
          &String.replace(
            &1,
            "forward \"/mailbox\", Plug.Swoosh.MailboxPreview\n",
            "forward \"/mailbox\", Plug.Swoosh.MailboxPreview\n      get \"/seed\", DevController, :seed\n"
          )
        )
        |> add("dashboard")

      assert routed(grown) =~ ~s(import Phoenix.LiveDashboard.Router)
      assert routed(grown) =~ ~r/live_dashboard "\/dashboard".*forward "\/mailbox".*get "\/seed"/s
    end
  end

  describe "what it cannot read, it leaves to the text merge" do
    test "two items known by the same name" do
      base = router(~w(html live))
      theirs = router(~w(html live dashboard))

      twice =
        String.replace(
          base,
          ~s(get "/", PageController, :home),
          ~s(get "/", PageController, :home\n    get "/", PageController, :other)
        )

      assert RouterFile.merge(twice, base, theirs) == :fallback
    end

    test "a router that does not parse" do
      base = router(~w(html live))

      assert RouterFile.merge(
               "defmodule TestWeb.Router do\n  scope \"/\" do\nend\n",
               base,
               router(~w(html live dashboard))
             ) == :fallback
    end
  end
end
