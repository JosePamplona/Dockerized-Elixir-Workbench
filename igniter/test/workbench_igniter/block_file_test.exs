defmodule WorkbenchIgniter.BlockFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.BlockFile

  @helper "test/test_helper.exs"
  @start "ExUnit.start()\n"

  describe "put/5" do
    test "the block stands above the anchor, once" do
      igniter =
        test_project(files: %{@helper => @start})
        |> BlockFile.put(@helper, "coveralls", "Mimic.copy(File)", before: "ExUnit.start()")
        |> apply_igniter!()

      assert igniter.assigns[:test_files][@helper] ==
               """
               # >>> coveralls
               Mimic.copy(File)
               # <<< coveralls

               ExUnit.start()
               """

      again =
        BlockFile.put(igniter, @helper, "coveralls", "Mimic.copy(File)", before: "ExUnit.start()")

      assert_unchanged(again, @helper)
    end

    test "a second owner gets its own block, and the first keeps its place" do
      content =
        test_project(files: %{@helper => @start})
        |> BlockFile.put(@helper, "coveralls", "Mimic.copy(File)", before: "ExUnit.start()")
        |> apply_igniter!()
        |> BlockFile.put(@helper, "health_endpoint", "Mimic.copy(MyApp.Repo)\nMimic.copy(System)",
          before: "ExUnit.start()",
          note: "the modules its controller test copies"
        )
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files][@helper])

      assert content ==
               """
               # >>> coveralls
               Mimic.copy(File)
               # <<< coveralls

               # >>> health_endpoint — the modules its controller test copies
               Mimic.copy(MyApp.Repo)
               Mimic.copy(System)
               # <<< health_endpoint

               ExUnit.start()
               """

      assert BlockFile.owners(content) == ["coveralls", "health_endpoint"]
      assert BlockFile.block(content, "coveralls") == {:ok, "Mimic.copy(File)\n"}
    end

    test "re-run with other options replaces the block where it stands" do
      content =
        test_project(files: %{@helper => @start})
        |> BlockFile.put(@helper, "coveralls", "Mimic.copy(File)", before: "ExUnit.start()")
        |> apply_igniter!()
        |> BlockFile.put(@helper, "openai", "Mimic.copy(Finch)", before: "ExUnit.start()")
        |> apply_igniter!()
        |> BlockFile.put(@helper, "coveralls", "Mimic.copy(File, type_check: true)",
          before: "ExUnit.start()"
        )
        |> apply_igniter!()
        |> then(& &1.assigns[:test_files][@helper])

      assert content ==
               """
               # >>> coveralls
               Mimic.copy(File, type_check: true)
               # <<< coveralls

               # >>> openai
               Mimic.copy(Finch)
               # <<< openai

               ExUnit.start()
               """

      assert BlockFile.owners(content) == ["coveralls", "openai"]
    end

    test "the anchor decides where a block is born, never where it lives" do
      moved = """
      ExUnit.start()

      # >>> coveralls
      Mimic.copy(File)
      # <<< coveralls
      """

      assert {:ok, content} =
               BlockFile.put_text(moved, "coveralls", "Mimic.copy(File, type_check: true)",
                 before: "ExUnit.start()"
               )

      assert content ==
               """
               ExUnit.start()

               # >>> coveralls
               Mimic.copy(File, type_check: true)
               # <<< coveralls
               """
    end

    test "no anchor, or no line matching it: the end" do
      assert {:ok, content} = BlockFile.put_text("a\nb\n", "credo", "mix credo --strict")
      assert content == "a\nb\n\n# >>> credo\nmix credo --strict\n# <<< credo\n"

      assert {:ok, ^content} =
               BlockFile.put_text("a\nb\n", "credo", "mix credo --strict", before: "nowhere")
    end

    test "a project without the file gets it, starting from :create" do
      igniter =
        test_project()
        |> BlockFile.put(".githooks/pre-commit", "credo", "mix credo --strict",
          create: "#!/bin/sh\nset -e\n"
        )
        |> apply_igniter!()

      assert igniter.assigns[:test_files][".githooks/pre-commit"] ==
               """
               #!/bin/sh
               set -e

               # >>> credo
               mix credo --strict
               # <<< credo
               """
    end

    test "another comment marker" do
      assert {:ok, content} =
               BlockFile.put_text("version: \"3\"\n", "db_admin", "  adminer:", comment: "##")

      assert content == "version: \"3\"\n\n## >>> db_admin\n  adminer:\n## <<< db_admin\n"
      assert BlockFile.owners(content, comment: "##") == ["db_admin"]
    end

    test "an owner is a cartridge name" do
      assert_raise ArgumentError, ~r/\[a-z0-9_\]\+/, fn ->
        BlockFile.put_text("", "Not A Name", "x")
      end
    end
  end

  describe "drop/4" do
    test "leaves the file as if the cartridge had never passed" do
      before = @start

      igniter =
        test_project(files: %{@helper => before})
        |> BlockFile.put(@helper, "coveralls", "Mimic.copy(File)", before: "ExUnit.start()")
        |> apply_igniter!()
        |> BlockFile.put(@helper, "openai", "Mimic.copy(Finch)", before: "ExUnit.start()")
        |> apply_igniter!()

      both = igniter.assigns[:test_files][@helper]

      assert {:ok, one} = BlockFile.drop_text(both, "coveralls")

      assert one ==
               """
               # >>> openai
               Mimic.copy(Finch)
               # <<< openai

               ExUnit.start()
               """

      assert {:ok, ^before} = BlockFile.drop_text(one, "openai")
    end

    test "the seam is repaired, and only the seam" do
      content = """
      a


      # >>> credo
      mix credo
      # <<< credo

      b
      """

      assert {:ok, dropped} = BlockFile.drop_text(content, "credo")
      assert dropped == "a\n\n\nb\n"
    end

    test "an owner without a block, and a project without the file, are no-ops" do
      assert {:ok, "a\n"} = BlockFile.drop_text("a\n", "credo")

      igniter = test_project() |> BlockFile.drop(@helper, "credo")
      assert_unchanged(igniter)
    end
  end

  describe "a half-deleted block" do
    test "is an error, and raises naming the file and the owner" do
      broken = "# >>> credo\nmix credo\n"

      assert {:error, {:unterminated, "credo"}} = BlockFile.drop_text(broken, "credo")
      assert {:error, {:unterminated, "credo"}} = BlockFile.put_text(broken, "credo", "x")
      assert BlockFile.block(broken, "credo") == {:error, {:unterminated, "credo"}}

      assert_raise RuntimeError, ~r/\.githooks\/pre-commit: the block of credo opens/, fn ->
        test_project(files: %{".githooks/pre-commit" => broken})
        |> BlockFile.put(".githooks/pre-commit", "credo", "mix credo --strict")
        |> apply_igniter!()
      end
    end

    test "block/3 says :error when there is no block at all" do
      assert BlockFile.block("a\n", "credo") == :error
    end
  end
end
