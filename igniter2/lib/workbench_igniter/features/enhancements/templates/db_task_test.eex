defmodule Mix.Tasks.DbTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mock

  alias Mix.Tasks.Db

  # mix db
  describe "db run/1" do
    test "format DbSchema files to enable ExDoc to integrate them" do
      with_mocks [
        {File, [:passthrough], cp!: fn(_, _) -> :ok end},
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        output = capture_io(fn -> Db.run([]) end)

        assert String.split(output, "\n") == [
          "Formatting DbSchema files...",
          "Success! the DbSchema files were generated:",
          "  ./assets/exdoc/database.md",
          "  ./assets/exdoc/images/model-light.svg",
          "  ./assets/exdoc/images/model-dark.svg",
          ""
        ]
      end
    end
  end
end
