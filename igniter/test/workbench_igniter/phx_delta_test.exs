defmodule WorkbenchIgniter.PhxDeltaTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.PhxDelta

  describe "facts/1" do
    test "reads a default phx.new project's shape off the project" do
      {facts, _} = PhxDelta.facts(phx_test_project())

      assert %{app: :test, module: Test, ecto: true, database: "postgres", adapter: "bandit"} =
               facts

      assert %{
               mailer: true,
               gettext: true,
               esbuild: true,
               tailwind: true,
               html: true,
               live: true,
               dashboard: true
             } = facts

      # Igniter's in-memory phx.new writes no AGENTS.md; the flags say so.
      assert %{agents_md: false} = facts

      assert PhxDelta.flags(facts) ==
               ~w(--app test --module Test --database postgres --adapter bandit --no-agents-md)

      {facts, _} = PhxDelta.facts(WorkbenchIgniter.TestProject.new())
      assert %{agents_md: true} = facts

      assert PhxDelta.flags(facts) ==
               ~w(--app test --module Test --database postgres --adapter bandit)
    end

    test "turns absent capabilities into --no- flags" do
      facts = %{
        app: :test,
        module: Test,
        ecto: false,
        database: "sqlite3",
        adapter: "cowboy",
        mailer: false,
        gettext: true,
        esbuild: true,
        tailwind: false,
        html: true,
        live: false,
        dashboard: false,
        binary_id: true
      }

      assert PhxDelta.flags(facts) ==
               ~w(--app test --module Test --database sqlite3 --adapter cowboy --no-ecto --no-mailer --no-tailwind --no-live --no-dashboard --binary-id)
    end
  end

  describe "generate/1" do
    test "names the directories after the app, as phx.new does, digits included" do
      files =
        PhxDelta.generate(
          ~w(--app lorem_ipsum_9 --module LoremIpsum9 --database postgres --adapter bandit)
        )

      paths = Map.keys(files)

      assert "lib/lorem_ipsum_9_web/router.ex" in paths
      assert "lib/lorem_ipsum_9/mailer.ex" in paths
      assert "lib/lorem_ipsum_9.ex" in paths
      assert "lib/lorem_ipsum_9_web.ex" in paths
      assert "test/lorem_ipsum_9_web/controllers/error_json_test.exs" in paths
      refute Enum.any?(paths, &String.contains?(&1, "lorem_ipsum9"))
      assert files["lib/lorem_ipsum_9_web/router.ex"] =~ "defmodule LoremIpsum9Web.Router do"
    end
  end

  describe "the delta" do
    test "of a mailer: what phx.new generates for it, and only that" do
      {facts, _} = PhxDelta.facts(phx_test_project())
      %{created: created, changed: changed} = PhxDelta.delta(%{facts | mailer: false}, :mailer)

      assert Map.keys(created) == ["lib/test/mailer.ex"]
      assert created["lib/test/mailer.ex"] =~ "use Swoosh.Mailer, otp_app: :test"
      assert "mix.exs" in Map.keys(changed)
      assert "config/config.exs" in Map.keys(changed)
      {base, theirs} = changed["mix.exs"]
      refute base =~ ":swoosh"
      assert theirs =~ ~s|{:swoosh, "~> 1|
      refute Enum.any?(Map.keys(changed), &String.starts_with?(&1, "lib/test_web/controllers"))
      # phx.new's random secrets are not part of the delta.
      refute "lib/test_web/endpoint.ex" in Map.keys(changed)
      {base, theirs} = changed["config/config.exs"]

      assert Regex.run(~r/signing_salt: "[^"]*"/, base) ==
               Regex.run(~r/signing_salt: "[^"]*"/, theirs)
    end
  end

  describe "merge3/3" do
    test "brings the change in and keeps the project's own edits" do
      base = "a\nb\nc\n"
      theirs = "a\nb\nb2\nc\n"
      ours = "a0\nb\nc\n"
      assert {:ok, "a0\nb\nb2\nc\n"} = PhxDelta.merge3(ours, base, theirs)
    end

    test "reports a conflict with git's markers, resolving nothing" do
      assert {:conflict, merged} = PhxDelta.merge3("a\nB!\nc\n", "a\nb\nc\n", "a\nb2\nc\n")
      assert merged =~ "<<<<<<< project"
      assert merged =~ ">>>>>>> with the capability"
    end

    test "the end of the file is not an edit: one newline, none or two merge alike" do
      # Igniter writes one trailing newline; phx.new's AGENTS.md ends
      # with none and its errors.pot with two. A capability appending
      # at the end must not conflict with that byte.
      assert {:ok, "a\nb\nc\n"} = PhxDelta.merge3("a\nc\n", "a\nc", "a\nb\nc")
      assert {:ok, "a\nc\nd\n"} = PhxDelta.merge3("a\nc\n", "a\nc\n\n", "a\nc\nd\n\n")
    end
  end

  describe "generator/1" do
    test "names the generator, where it is recorded, and the installer at hand" do
      here = to_string(Application.spec(:phx_new, :vsn))

      {gen, _} = PhxDelta.generator(phx_test_project())
      assert %{project: ^here, source: "mix.exs", installer: ^here} = gen

      igniter =
        phx_test_project()
        |> Igniter.create_new_file("Dockerfile.local", ~s|ARG PHX_NEW="9.9.9"\n|)
        |> apply_igniter!()

      {gen, _} = PhxDelta.generator(igniter)
      assert %{project: "9.9.9", source: "Dockerfile.local", installer: ^here} = gen
    end
  end

  describe "generator_check/1" do
    test "passes on a project generated by the installer at hand" do
      assert {:ok, _} = PhxDelta.generator_check(phx_test_project())
    end

    test "refuses a project generated by another phx.new, naming both versions" do
      igniter =
        phx_test_project()
        |> Igniter.update_file("mix.exs", fn source ->
          Rewrite.Source.update(
            source,
            :content,
            &Regex.replace(~r/\{:phoenix, "~> [\d.]+"\}/, &1, ~s|{:phoenix, "~> 9.9.9"}|)
          )
        end)
        |> apply_igniter!()

      assert {:error, _, message} = PhxDelta.generator_check(igniter)
      assert message =~ "generated by phx.new 9.9.9"
      assert message =~ "mix archive.install hex phx_new 9.9.9"
    end

    test "reads the generator the workbench stamped into the workspace" do
      igniter =
        phx_test_project()
        |> Igniter.create_new_file("Dockerfile.local", ~s|ARG PHX_NEW="9.9.9"\n|)
        |> apply_igniter!()

      assert {:error, _, message} = PhxDelta.generator_check(igniter)
      assert message =~ "generated by phx.new 9.9.9"
      assert message =~ "ARG PHX_NEW in Dockerfile.local"
    end

    test "the stamp outranks mix.exs: bumping Phoenix does not make it another project" do
      igniter =
        phx_test_project()
        |> Igniter.create_new_file(
          "Dockerfile.local",
          ~s|ARG PHX_NEW="#{Application.spec(:phx_new, :vsn)}"\n|
        )
        |> Igniter.update_file("mix.exs", fn source ->
          Rewrite.Source.update(
            source,
            :content,
            &Regex.replace(~r/\{:phoenix, "~> [\d.]+"\}/, &1, ~s|{:phoenix, "~> 9.9.9"}|)
          )
        end)
        |> apply_igniter!()

      assert {:ok, _} = PhxDelta.generator_check(igniter)
    end

    test "says nothing about a requirement phx.new did not write" do
      igniter =
        phx_test_project()
        |> Igniter.update_file("mix.exs", fn source ->
          Rewrite.Source.update(
            source,
            :content,
            &Regex.replace(~r/\{:phoenix, "~> [\d.]+"\}/, &1, ~s|{:phoenix, "~> 1.8"}|)
          )
        end)
        |> apply_igniter!()

      assert {:ok, _} = PhxDelta.generator_check(igniter)
    end
  end
end
