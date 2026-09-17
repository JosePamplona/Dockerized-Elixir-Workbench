defmodule WorkbenchIgniter.EnvFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.EnvFile

  defp files(igniter), do: apply_igniter!(igniter).assigns[:test_files]

  test "an entry goes into both files, at the end, once" do
    igniter =
      test_project(files: %{".env" => "PORT=\"4000\"\n", ".env.sample" => "PORT=\"4000\"\n"})
      |> EnvFile.entry("Where the release finds its database.", ~s|DATABASE_URL="ecto://x"|)

    assert files(igniter)[".env"] ==
             "PORT=\"4000\"\n\n# Where the release finds its database.\nDATABASE_URL=\"ecto://x\"\n"

    assert files(igniter)[".env.sample"] == files(igniter)[".env"]

    # The first KEY= marks it as there: another value is the project's own.
    again = igniter |> apply_igniter!() |> EnvFile.entry("Again.", ~s|DATABASE_URL="ecto://y"|)
    assert_unchanged(again, ".env")
    assert_unchanged(again, ".env.sample")
  end

  test "a secret goes into .env, its blanked-out line into the sample that is committed" do
    files =
      test_project(files: %{".env" => "A=1\n", ".env.sample" => "A=1\n"})
      |> EnvFile.entry("The key.", ~s|API_KEY="s3cr3t"|, ~s|API_KEY=""|)
      |> files()

    assert files[".env"] =~ ~s|API_KEY="s3cr3t"|
    assert files[".env.sample"] =~ ~s|API_KEY=""|
    refute files[".env.sample"] =~ "s3cr3t"
  end

  test "a project without the files gets them, with the entry alone" do
    files = test_project() |> EnvFile.entry("One.", "ONE=1") |> files()
    assert files[".env"] == "# One.\nONE=1\n"
    assert files[".env.sample"] == "# One.\nONE=1\n"
  end
end
