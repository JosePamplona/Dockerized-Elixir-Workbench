defmodule ConsoleWeb.CartridgesTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Cartridges

  # A status with two cartridges in: ash with --with ash_oban, and rest.
  @status %{
    "project" => %{
      "cartridges" => [
        %{"name" => "ash", "installed" => true, "state" => %{"with" => ["ash_oban"]}},
        %{"name" => "rest", "installed" => true},
        %{"name" => "graphql", "installed" => false}
      ]
    }
  }
  @ash %{"name" => "ash", "state" => %{"with" => ["ash_oban"]}}

  describe "holds?/3" do
    test "an item without a when holds" do
      assert Cartridges.holds?(@status, @ash, %{"path" => "/oban"})
    end

    test "an option at a value reads the cartridge's own state, a list for any one" do
      with_ = &%{"when" => %{"option" => "with", "value" => &1}}

      assert Cartridges.holds?(@status, @ash, with_.("ash_oban"))
      refute Cartridges.holds?(@status, @ash, with_.("ash_cloak"))
      assert Cartridges.holds?(@status, @ash, with_.(["ash_cloak", "ash_oban"]))

      refute Cartridges.holds?(@status, @ash, %{
               "when" => %{"option" => "api", "value" => "graphql"}
             })
    end

    # coverage's `mix cover` is planted by its own --exdoc, and whether
    # the exdoc cartridge is in says nothing about that file.
    test "an option condition reads what the cartridge was inserted with" do
      coverage = %{"name" => "coverage", "state" => %{"exdoc" => true, "githook" => false}}

      assert Cartridges.holds?(@status, coverage, %{"when" => %{"option" => "exdoc"}})
      refute Cartridges.holds?(@status, coverage, %{"when" => %{"option" => "githook"}})

      refute Cartridges.holds?(@status, %{"name" => "coverage"}, %{
               "when" => %{"option" => "exdoc"}
             })
    end

    test "a cartridge condition asks whether that one is in" do
      assert Cartridges.holds?(@status, @ash, %{"when" => %{"cartridge" => "rest"}})
      refute Cartridges.holds?(@status, @ash, %{"when" => %{"cartridge" => "graphql"}})
    end
  end

  describe "satisfies?/3: a requirement's state, off the status" do
    # A `:csv` option answers with a list: coverage's `--md-report`
    # asks test_doubles for Mimic among its doubles, and the console
    # shut the switch on a project that had it.
    @doubles %{
      "project" => %{
        "cartridges" => [
          %{
            "name" => "test_doubles",
            "installed" => true,
            "state" => %{"double" => ["mimic", "mox"]}
          }
        ]
      }
    }

    test "a state answered with a list is met when it carries the value asked" do
      assert Cartridges.satisfies?(@doubles, "test_doubles", %{"double" => "mimic"})
      assert Cartridges.satisfies?(@doubles, "test_doubles", %{"double" => "mox"})
      refute Cartridges.satisfies?(@doubles, "test_doubles", %{"double" => "hammox"})

      one =
        put_in(@doubles, ["project", "cartridges"], [
          %{"name" => "test_doubles", "installed" => true, "state" => %{"double" => ["mox"]}}
        ])

      refute Cartridges.satisfies?(one, "test_doubles", %{"double" => "mimic"})
    end

    @on_mysql %{
      "project" => %{
        "cartridges" => [
          %{"name" => "ecto", "installed" => true, "state" => %{"database" => "mysql"}}
        ]
      }
    }

    test "a value is met by that value; a list, by any one of its values" do
      assert Cartridges.satisfies?(@on_mysql, "ecto", %{})
      assert Cartridges.satisfies?(@on_mysql, "ecto", %{"database" => "mysql"})
      refute Cartridges.satisfies?(@on_mysql, "ecto", %{"database" => "postgres"})
      assert Cartridges.satisfies?(@on_mysql, "ecto", %{"database" => ~w(postgres mysql mssql)})
      refute Cartridges.satisfies?(@on_mysql, "ecto", %{"database" => ~w(postgres sqlite3)})
      refute Cartridges.satisfies?(@status, "ecto", %{"database" => ~w(postgres mysql)})
    end

    test "and said: the values, the last after an or" do
      assert Cartridges.requirement("ecto", %{"database" => "postgres"}) ==
               "ecto with database postgres"

      assert Cartridges.requirement("ecto", %{"database" => ~w(postgres mysql mssql)}) ==
               "ecto with database postgres, mysql or mssql"
    end
  end

  test "container_reading/1: exited with 0 is an absence, exited otherwise says its code" do
    assert Cartridges.container_reading(%{"State" => "running", "Health" => "healthy"}) ==
             {"healthy", "good"}

    assert Cartridges.container_reading(%{"State" => "running", "Health" => ""}) ==
             {"running", "good"}

    assert Cartridges.container_reading(%{"State" => "running", "Health" => "starting"}) ==
             {"starting", "warn busy"}

    assert Cartridges.container_reading(%{"State" => "exited", "Health" => "", "ExitCode" => 0}) ==
             {"exited", "off"}

    assert Cartridges.container_reading(%{"State" => "exited", "Health" => "", "ExitCode" => 137}) ==
             {"exited 137", "bad"}

    # Docker keeps a stopped container's last health: a crash reads its code, not `unhealthy`.
    assert Cartridges.container_reading(%{
             "State" => "exited",
             "Health" => "unhealthy",
             "ExitCode" => 1
           }) == {"exited 1", "bad"}

    assert Cartridges.container_reading(%{"State" => "dead"}) == {"dead", "bad"}
  end

  describe "fill_path/2: a door's path, with what the project carries" do
    @door "{path}/live"
    @options [%{"name" => "path", "default" => "/health"}]

    test "the state's value; the option's default for a cartridge that is not in" do
      assert Cartridges.fill_path(@door, %{
               "state" => %{"path" => "/status"},
               "options" => @options
             }) ==
               "/status/live"

      assert Cartridges.fill_path(@door, %{"state" => %{}, "options" => @options}) ==
               "/health/live"
    end

    test "an empty value is a value: health_probe at the root opens /live, not the default's" do
      assert Cartridges.fill_path(@door, %{"state" => %{"path" => ""}, "options" => @options}) ==
               "/live"
    end

    test "a placeholder nobody fills leaves nothing behind" do
      assert Cartridges.fill_path("/x{gone}", %{}) == "/x"
    end
  end
end
