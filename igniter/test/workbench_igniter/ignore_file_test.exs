defmodule WorkbenchIgniter.IgnoreFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.IgnoreFile

  describe "entry/3" do
    test "goes at the end of .gitignore once, and makes the file when there is none" do
      igniter =
        test_project(files: %{".gitignore" => "/_build/\n"})
        |> IgnoreFile.entry("The language server's.", "/.elixir_ls/")
        |> apply_igniter!()

      assert igniter.assigns[:test_files][".gitignore"] ==
               "/_build/\n\n# The language server's.\n/.elixir_ls/\n"

      again = IgnoreFile.entry(igniter, "The language server's.", "/.elixir_ls/")
      assert_unchanged(again, ".gitignore")
    end

    test "ignore_file?/1 knows its two, wherever they are" do
      assert IgnoreFile.ignore_file?(".gitignore")
      assert IgnoreFile.ignore_file?("assets/.dockerignore")
      refute IgnoreFile.ignore_file?("mix.exs")
    end
  end

  describe "merge/3" do
    test "the capability's lines go in once at the end, past what the project appended there" do
      base = "# tarball\napp-*.tar\n"

      theirs =
        "# tarball\napp-*.tar\n\n# Ignore assets that are produced by build tools.\n/priv/static/assets/\n\nnpm-debug.log\n"

      ours = "# tarball\napp-*.tar\n\n# Secrets required to configure the application.\n.env\n"

      assert {:ok, merged} = IgnoreFile.merge(ours, base, theirs)

      assert merged ==
               "# tarball\napp-*.tar\n\n# Secrets required to configure the application.\n.env\n\n# Ignore assets that are produced by build tools.\n/priv/static/assets/\n\nnpm-debug.log\n"

      # Applied again, nothing doubles.
      assert {:ok, ^merged} = IgnoreFile.merge(merged, base, theirs)
    end

    test "a line the capability takes away goes, and one the project already has is not repeated" do
      assert {:ok, "a\n/priv/static/assets/\n"} =
               IgnoreFile.merge(
                 "a\nold\n/priv/static/assets/\n",
                 "a\nold\n",
                 "a\n/priv/static/assets/\n"
               )
    end
  end
end
