defmodule WorkbenchIgniter.Features.GuidelinesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Guidelines

  # Nothing here reaches the network: the URL is a closed port, so the
  # download fails at once and the installer plants its placeholder —
  # the same file, listed in the same two places, either way.
  @url "http://localhost:1/guide.md"

  defp with_exdoc(argv) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.exdoc", [])
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.guidelines", argv)
  end

  describe "mix workbench.install.guidelines" do
    test "plants the page and lists it in the docs site" do
      files =
        with_exdoc(["--url", @url])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      assert files["guides/coding.md"] =~ "# Coding guidelines"
      # The two lists exdoc keeps, each with the page appended and its
      # own pages untouched.
      assert files["mix.exs"] =~ ~s|{"guides/coding.md", [title: "Coding guidelines"]}|
      assert files["mix.exs"] =~ ~s|{"README.md", [title: "Overview"]}|

      support =
        Regex.run(~r/Support: \[(.*?)\]/s, files["mix.exs"]) |> List.last()

      assert support =~ ~s|"guides/coding.md"|
    end

    test "warns and plants a placeholder naming the URL when the download fails" do
      igniter = with_exdoc(["--url", @url])

      assert Enum.any?(igniter.warnings, &(&1 =~ "Could not download the coding guidelines"))

      assert igniter
             |> apply_igniter!()
             |> Map.get(:assigns)
             |> Map.get(:test_files)
             |> Map.get("guides/coding.md") =~ @url
    end

    test "refuses without a URL: it is the page the cartridge installs" do
      igniter = with_exdoc([])

      assert [issue] = igniter.issues
      assert issue =~ "--url is required"
    end

    test "is a no-op with a notice when the page is already there" do
      with_exdoc(["--url", @url])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.guidelines", ["--url", @url])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already exists"))
    end
  end

  describe "requires exdoc" do
    test "refuses, naming it, while the docs site is not in" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.guidelines", ["--url", @url])

      assert [issue] = igniter.issues
      assert issue =~ "guidelines builds on exdoc"
      assert issue =~ "./wb.sh add exdoc"
    end

    test "the manifest says so, and exdoc no longer takes the URL" do
      assert Guidelines.requires() == ["exdoc"]

      exdoc_options = Keyword.keys(WorkbenchIgniter.Features.Exdoc.info([], nil).schema)
      refute :guidelines_url in exdoc_options
    end
  end
end
