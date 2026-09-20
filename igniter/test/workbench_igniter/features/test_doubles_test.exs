defmodule WorkbenchIgniter.Features.TestDoublesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.TestDoubles

  @task "workbench.install.test_doubles"
  @helper "test/test_helper.exs"

  describe "mix workbench.install.test_doubles" do
    test "without --double, the one the shelf's own tests need: mimic" do
      test_project()
      |> Igniter.compose_task(@task, [])
      |> assert_has_patch("mix.exs", """
      + | {:mimic, "~> 2.0", only: :test}
      """)
    end

    test "--double mox is Mox, and with --type-check it is Hammox, which wraps it" do
      test_project()
      |> Igniter.compose_task(@task, ~w(--double mox))
      |> assert_has_patch("mix.exs", """
      + | {:mox, "~> 1.2", only: :test}
      """)

      test_project()
      |> Igniter.compose_task(@task, ~w(--double mox --type-check))
      |> assert_has_patch("mix.exs", """
      + | {:hammox, "~> 1.0", only: :test}
      """)
    end

    test "both, comma-separated, and a second run adds the other" do
      both =
        test_project()
        |> Igniter.compose_task(@task, ~w(--double mimic,mox))
        |> apply_igniter!()

      assert {%{double: ["mimic", "mox"], type_check: false}, _} = TestDoubles.state(both)

      grown =
        test_project()
        |> Igniter.compose_task(@task, ~w(--double mimic))
        |> apply_igniter!()
        |> Igniter.compose_task(@task, ~w(--double mox))
        |> apply_igniter!()

      assert {%{double: ["mimic", "mox"]}, _} = TestDoubles.state(grown)
    end

    test "re-running it with the same double is a no-op" do
      test_project()
      |> Igniter.compose_task(@task, [])
      |> apply_igniter!()
      |> Igniter.compose_task(@task, [])
      |> assert_unchanged()
    end

    test "a double that is not one of the two refuses the run" do
      igniter = test_project() |> Igniter.compose_task(@task, ~w(--double meck))

      assert Enum.any?(igniter.issues, &(&1 =~ "--double must be one of mimic, mox"))
    end
  end

  describe "the way in" do
    test "each cartridge owns its block, above ExUnit.start()" do
      content =
        test_project(files: %{@helper => "ExUnit.start()\n"})
        |> Igniter.compose_task(@task, [])
        |> apply_igniter!()
        |> TestDoubles.copy("coveralls", ["File"])
        |> apply_igniter!()
        |> TestDoubles.copy("health_endpoint", ["MyApp.Repo", "System"],
          note: "what its controller test makes raise"
        )
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files][@helper])

      assert content ==
               """
               # >>> coveralls
               Mimic.copy(File)
               # <<< coveralls

               # >>> health_endpoint — what its controller test makes raise
               Mimic.copy(MyApp.Repo)
               Mimic.copy(System)
               # <<< health_endpoint

               ExUnit.start()
               """
    end

    test "a module registered twice is written once, and the block grows by the new one" do
      igniter =
        test_project(files: %{@helper => "ExUnit.start()\n"})
        |> Igniter.compose_task(@task, [])
        |> apply_igniter!()
        |> TestDoubles.copy("health_endpoint", ["MyApp.Repo"])
        |> apply_igniter!()

      assert_unchanged(TestDoubles.copy(igniter, "health_endpoint", ["MyApp.Repo"]), @helper)

      grown =
        igniter
        |> TestDoubles.copy("health_endpoint", ["MyApp.Repo", "System"])
        |> apply_igniter!()

      assert grown.assigns[:test_files][@helper] =~
               "# >>> health_endpoint\nMimic.copy(MyApp.Repo)\nMimic.copy(System)\n# <<< health_endpoint"
    end

    test "with --type-check in, every copy asks for it, and a mock is Hammox's" do
      igniter =
        test_project(files: %{@helper => "ExUnit.start()\n"})
        |> Igniter.compose_task(@task, ~w(--double mimic,mox --type-check))
        |> apply_igniter!()

      assert igniter
             |> TestDoubles.copy("coveralls", ["File"])
             |> apply_igniter!()
             |> then(& &1.assigns[:test_files][@helper]) =~
               "Mimic.copy(File, type_check: true)"

      assert igniter
             |> TestDoubles.defmock("openai", [{"MyApp.OpenAI.Mock", "MyApp.OpenAI.Client"}])
             |> apply_igniter!()
             |> then(& &1.assigns[:test_files][@helper]) =~
               "Hammox.defmock(MyApp.OpenAI.Mock, for: MyApp.OpenAI.Client)"
    end

    test "forget/2 takes one cartridge's block away and leaves the other's" do
      content =
        test_project(files: %{@helper => "ExUnit.start()\n"})
        |> Igniter.compose_task(@task, [])
        |> apply_igniter!()
        |> TestDoubles.copy("coveralls", ["File"])
        |> apply_igniter!()
        |> TestDoubles.copy("health_endpoint", ["System"])
        |> apply_igniter!()
        |> TestDoubles.forget("coveralls")
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files][@helper])

      assert content ==
               """
               # >>> health_endpoint
               Mimic.copy(System)
               # <<< health_endpoint

               ExUnit.start()
               """
    end

    test "a project without a test helper gets one, the copies above ExUnit.start()" do
      igniter =
        test_project()
        |> Igniter.compose_task(@task, [])
        |> apply_igniter!()
        |> TestDoubles.copy("coveralls", ["File"])
        |> apply_igniter!()

      assert igniter.assigns[:test_files][@helper] ==
               "# >>> coveralls\nMimic.copy(File)\n# <<< coveralls\n\nExUnit.start()\n"
    end
  end
end
