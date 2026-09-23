defmodule ConsoleWeb.BoxInstallTest do
  @moduledoc """
  The box's Installation screen keeps what the cartridge went in with:
  the line says it, and the fields start from it — locked, and open
  again for the cartridges that can be run to add (`rerun: adds`),
  which used to fall back to their defaults and so forget.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias ConsoleWeb.Box

  @box %{
    "name" => "ecto",
    "options" => [
      %{
        "name" => "database",
        "choices" => [%{"value" => "postgres"}, %{"value" => "mysql"}],
        "default" => "postgres",
        "type" => "string"
      },
      %{"name" => "binary_id", "type" => "boolean", "default" => false}
    ]
  }

  test "locked, the line is the insert's own argv" do
    insert = %{"argv" => ["--database", "mysql", "--binary-id"]}
    assert Box.line_argv(@box, %{}, insert, true) == ["--database", "mysql", "--binary-id"]
  end

  test "open, the line is what the form says" do
    insert = %{"argv" => ["--database", "mysql"]}
    # The reader is looking at sqlite3 now, whatever it went in with.
    assert Box.line_argv(@box, %{"database" => "sqlite3"}, insert, false) ==
             ["--database", "sqlite3"]
  end

  defp screen(box, status, opts \\ []) do
    render_component(&ConsoleWeb.Box.box/1,
      box: box,
      status: status,
      catalog: [box],
      screen: Keyword.get(opts, :screen, "install"),
      paper: "readme",
      papers: [],
      args: Keyword.get(opts, :args, %{}),
      recipe: opts[:recipe]
    )
  end

  defp in_project(name, opts \\ []) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => opts[:inserts] || []},
      "project" => %{"cartridges" => [%{"name" => name, "installed" => true}]}
    }
  end

  test "archived: the console does not force it, and says the line that does" do
    box = Map.put(@box, "archived", "2026-09-20: chiefs_setup's collection covers it")
    html = screen(box, %{"exists" => true, "git" => %{"repo" => true, "clean" => true}})

    # The command the reader would have to run is the honest one, flag
    # included; the button beside it is unlit, with the reason.
    assert html =~ "./wb.sh add --archived ecto"
    assert html =~ "Archived"
    assert html =~ "chiefs_setup&#39;s collection covers it"
    assert html =~ "retired: not offered for new projects"
    refute html =~ ~s(phx-value-args="add ecto")
  end

  test "not in: the insert foot alone" do
    html = screen(@box, %{"exists" => true, "git" => %{"repo" => true, "clean" => true}})
    assert html =~ "./wb.sh add ecto"
    assert html =~ "Insert cartridge"
    refute html =~ "Eject"
  end

  test "in and done: the eject foot alone, with the line it is" do
    html = screen(@box, in_project("ecto"))
    assert html =~ "./wb.sh eject ecto"
    assert html =~ ">Eject</button>"
    # A button that says "already inserted" is a state, not an action.
    refute html =~ "Already inserted"
    refute html =~ "./wb.sh add ecto"
  end

  test "in and rerunnable: both feet, each with its own line" do
    box = @box |> Map.put("rerun", "adds") |> Map.put("adds", "all")
    html = screen(box, in_project("ecto"))
    assert html =~ "./wb.sh add ecto"
    assert html =~ "./wb.sh eject ecto"
    assert html =~ "Add to cartridge"
    assert html =~ ">Eject</button>"
  end

  # coverage's shape: the report was fixed at the insert, the mix task
  # and the hook block are pieces a second run still puts in.
  @coverage %{
    "name" => "coverage",
    "rerun" => "adds",
    "adds" => ["md_report", "githook"],
    "requires" => [],
    "offers" => [],
    "console" => %{"doors" => [], "tabs" => []},
    "deps" => [],
    "options" => [
      %{"name" => "html_theme", "type" => "string", "default" => "custom"},
      %{"name" => "md_report", "type" => "boolean", "default" => false},
      %{"name" => "githook", "type" => "boolean", "default" => false}
    ]
  }

  test "in and only some options addable: those take input and the rest do not" do
    html = screen(@coverage, in_project("coverage"), screen: "install")

    # The form is not locked whole: there is something to add.
    refute html =~ ~s(class="insert locked")
    assert html =~ "Add to cartridge"
    assert html =~ "--md-report &amp;&amp; --githook are the pieces it still adds"

    # One input per option, and only the two pieces are movable.
    fixed = html |> String.split(~s(name="opt[html_theme]")) |> Enum.at(1) || ""
    assert String.slice(fixed, 0, 200) =~ "disabled"

    for piece <- ~w(md_report githook) do
      [_, after_it | _] = String.split(html, ~s(id="opt-#{piece}"))
      refute String.slice(after_it, 0, 120) =~ "disabled"
    end
  end

  test "in and nothing a second run adds: no form to fill and no verb to press" do
    box = @coverage |> Map.put("rerun", "noop") |> Map.put("adds", "none")
    html = screen(box, in_project("coverage"), screen: "install")

    assert html =~ ~s(class="insert locked")
    refute html =~ "Add to cartridge"
    refute html =~ "./wb.sh add coverage"
  end

  test "in from birth, with no Insert commit, the fields read what the project reports" do
    status =
      put_in(in_project("ecto"), ["project", "cartridges"], [
        %{
          "name" => "ecto",
          "installed" => true,
          "state" => %{"database" => "mysql", "binary_id" => true}
        }
      ])

    html = screen(@box, status)
    assert html =~ ~r{name="opt\[binary_id\]"[^>]*checked}
    assert html =~ ~r{value="mysql"[^>]*checked}
    refute html =~ ~r{value="postgres"[^>]*checked}
  end

  test "a default is the field's placeholder, never its value" do
    box = %{
      "name" => "exdoc",
      "options" => [
        %{"name" => "minimum", "type" => "string", "default" => "80"},
        %{"name" => "repo_url", "type" => "string", "detected" => true},
        %{"name" => "homepage_url", "type" => "string"}
      ]
    }

    html = screen(box, %{"exists" => true, "project" => %{"cartridges" => []}})

    # Empty, showing what an empty field means: the default, where it
    # comes from when the installer reads it off the project, or the type.
    assert html =~ ~r{id="opt-minimum"[^>]*placeholder="80"}
    refute html =~ ~r{id="opt-minimum"[^>]*value=}
    assert html =~ ~r{id="opt-repo_url"[^>]*placeholder="read off the project"}
    assert html =~ ~r{id="opt-homepage_url"[^>]*placeholder="string"}
    # And an empty field leaves its flag out of the line.
    assert Box.argv(box, %{"minimum" => ""}) == []
    assert Box.argv(box, %{"minimum" => "90"}) == ["--minimum", "90"]
  end

  test "a default read off the project shows the value the status read for it" do
    box = %{
      "name" => "exdoc",
      "options" => [
        %{"name" => "repo_url", "type" => "string", "detected" => true},
        %{"name" => "project_name", "type" => "string", "detected" => true},
        %{
          "name" => "module_groups",
          "type" => "string",
          "detected" => true,
          "choices" => [%{"value" => "layers"}, %{"value" => "ash"}]
        }
      ]
    }

    status = %{
      "exists" => true,
      "project" => %{
        "cartridges" => [
          %{
            "name" => "exdoc",
            "installed" => false,
            "detected" => %{
              "repo_url" => "https://github.com/acme/lorem",
              "project_name" => nil,
              "module_groups" => "ash"
            }
          }
        ]
      }
    }

    html = screen(box, status)

    # The value the insert would write, as the placeholder, and where
    # it comes from as the tag; never filled in.
    assert html =~ ~r{id="opt-repo_url"[^>]*placeholder="https://github.com/acme/lorem"}
    refute html =~ ~r{id="opt-repo_url"[^>]*value=}
    assert html =~ "read off the project"
    # Nothing read: the field says where it would come from.
    assert html =~ ~r{id="opt-project_name"[^>]*placeholder="read off the project"}
    # A choice read off the project carries the default's tag.
    assert html =~ ~r{value="ash".*?tag def">default<}s
    refute html =~ ~r{value="layers"[^<]*<[^>]*>[^<]*<span[^>]*tag def">default<}
    # Empty, the flag stays out: the installer reads the same value.
    assert Box.argv(box, %{"repo_url" => ""}) == []
  end

  test "an option with a declared shape asks for that shape, and says which it is" do
    box = %{
      "name" => "exdoc",
      "options" => [
        %{"name" => "repo_url", "type" => "string", "format" => "url"},
        %{"name" => "minimum", "type" => "string", "format" => "integer 0..100"},
        %{"name" => "project_name", "type" => "string"}
      ]
    }

    html = screen(box, %{"exists" => true, "project" => %{"cartridges" => []}})

    # The field is a URL field, and the flag says `url` where an
    # unshaped string says `text`.
    assert html =~ ~r{<input type="url"[^>]*id="opt-repo_url"[^>]*placeholder="url"}
    assert html =~ "a URL (https://example.com/page)"
    # The browser is held to the installer's rule, not its own looser
    # one (`type="url"` takes `ftp://…`), and the field writes the
    # scheme for the reader.
    assert html =~ ~s|pattern="https?://.+"|
    assert html =~ ~s|phx-hook="UrlField"|
    assert html =~ ~s(<span class="kind">url</span>)
    assert html =~ ~r{<input type="text" inputmode="numeric"[^>]*id="opt-minimum"}
    assert html =~ ~s(<span class="kind">integer 0..100</span>)
    assert html =~ ~r{<input type="text" id="opt-project_name"[^>]*placeholder="string"}
    assert html =~ ~s(<span class="kind">text</span>)
  end

  # The box wraps what it is given, so the markup's own newlines and
  # indentation would be read as part of the command: the line is built
  # whole and interpolated once.
  test "the command box holds the line and nothing else" do
    html =
      screen(@box, %{"exists" => true, "project" => %{"cartridges" => []}},
        args: %{"database" => "mysql"}
      )

    assert html =~ ~s(<div class="cmd">./wb.sh add ecto --database mysql</div>)

    archived =
      screen(Map.put(@box, "archived", "2026-09-20: covered by another box"), %{
        "exists" => true,
        "project" => %{"cartridges" => []}
      })

    assert archived =~ ~s(<div class="cmd">./wb.sh add --archived ecto</div>)
  end

  # A cartridge another box's installer brings in (coverage --exdoc
  # brings test_doubles) has no insert of its own, and used to read as
  # inserted by hand: the commit that carries its files is the other
  # box's, and the box says so.
  test "a cartridge that rode in with another box names the insert that carries it" do
    status = %{
      "exists" => true,
      "git" => %{
        "repo" => true,
        "clean" => true,
        "inserts" => [
          %{
            "sha" => "d2ec4831234567",
            "feature" => "coverage",
            "subject" => "Insert coverage --exdoc",
            "date" => "2026-09-22 10:00:00 +0200"
          }
        ]
      },
      "project" => %{
        "cartridges" => [
          %{"name" => "coverage", "installed" => true, "composes" => ["test_doubles"]},
          %{"name" => "test_doubles", "installed" => true}
        ]
      }
    }

    box = %{"name" => "test_doubles", "options" => []}

    assert {"with coverage", "off", why} = ConsoleWeb.Cartridges.origin(status, box)
    assert why =~ "d2ec483" and why =~ "Insert coverage --exdoc"
    assert ConsoleWeb.Box.files_unlit(box, status) =~ "came in with coverage's insert"

    # Nobody claims it: inserted by hand, as before.
    alone =
      put_in(status, ["project", "cartridges"], [%{"name" => "test_doubles", "installed" => true}])

    assert {"by hand", _, _} = ConsoleWeb.Cartridges.origin(alone, box)
  end

  # The box's third panel: the packages it puts in the project's
  # mix.exs, before it is in and after.
  describe "Packages" do
    @box_with_deps %{
      "name" => "exdoc",
      "options" => [],
      "requires" => [],
      "offers" => [],
      "console" => %{"doors" => [], "tabs" => []},
      "deps" => [
        %{
          "name" => "ex_doc",
          "requirement" => "~> 0.40",
          "opts" => %{"only" => ":dev", "runtime" => "false"}
        }
      ]
    }

    test "not in: the packages an insert would add, off the manifest" do
      html =
        screen(@box_with_deps, %{"exists" => true, "project" => %{"cartridges" => []}},
          screen: "box"
        )

      assert html =~ "ex_doc"
      assert html =~ "~&gt; 0.40"
      # The tuple's own options are noise in a table of versions.
      refute html =~ "only: :dev"
      # What the project would do with it is a column of its own, standing
      # unlit with its reason, never one missing from the table.
      assert html =~ ">mix.exs</th>"
      assert html =~ "locked"
      assert html =~ "the box is not in: nothing pins it yet"
      assert html =~ "the box is not in: no lock resolved it yet"
    end

    test "in: what the project pins and what its lock resolved, with an older insert marked" do
      status = %{
        "exists" => true,
        "project" => %{
          "cartridges" => [
            %{
              "name" => "exdoc",
              "installed" => true,
              "deps" => [
                %{
                  "name" => "ex_doc",
                  "declared" => "~> 0.40",
                  "pinned" => "~> 0.38",
                  "locked" => "0.38.2"
                }
              ]
            }
          ]
        }
      }

      html = screen(@box_with_deps, status, screen: "box")

      # The table says it all: the panel carries no legend of any kind.
      refute html =~ "insert would put in mix.exs"
      assert html =~ "0.38.2"
      # The pin that is not the box's is marked, and says why.
      assert html =~ ~r/class="asks warn"/
      assert html =~ "an insert older than the cartridge"
    end
  end

  describe "Packages, and what hex says" do
    @exdoc_box %{
      "name" => "exdoc",
      "options" => [],
      "requires" => [],
      "offers" => [],
      "console" => %{"doors" => [], "tabs" => []},
      "deps" => [%{"name" => "ex_doc", "requirement" => "~> 0.40", "opts" => %{}}]
    }

    defp with_hex(hex) do
      render_component(&ConsoleWeb.Box.box/1,
        box: @exdoc_box,
        status: %{"exists" => true, "project" => %{"cartridges" => []}},
        catalog: [@exdoc_box],
        screen: "box",
        paper: "readme",
        papers: [],
        args: %{},
        packages: hex,
        now: ~U[2026-09-23 12:00:00Z]
      )
    end

    test "a box that declares none says what its insert commit put in mix.exs" do
      base = %{
        "name" => "mailer",
        "options" => [],
        "requires" => [],
        "offers" => [],
        "base" => true,
        "console" => %{"doors" => [], "tabs" => []},
        "deps" => []
      }

      status = %{
        "exists" => true,
        "project" => %{
          "cartridges" => [%{"name" => "mailer", "installed" => true, "deps" => []}],
          "deps" => [
            %{"name" => "swoosh", "pinned" => "~> 1.16", "locked" => "1.19.7"},
            %{"name" => "phoenix", "pinned" => "~> 1.8.0", "locked" => "1.8.14"}
          ]
        }
      }

      html =
        render_component(&ConsoleWeb.Box.box/1,
          box: base,
          status: status,
          catalog: [base],
          screen: "box",
          paper: "readme",
          papers: [],
          args: %{},
          packages: %{},
          read_deps: [
            %{name: "swoosh", requirement: "~> 1.16", from: "1.8.14"},
            %{name: "gone", requirement: "~> 1.0", from: "1.8.14"}
          ],
          now: ~U[2026-09-23 12:00:00Z]
        )

      # What the commit wrote is the cartridge's own column, and it says
      # where it was read; the project's two columns come from mix.exs
      # and mix.lock as they do for any other box.
      assert html =~ "swoosh"
      assert html =~ "1.19.7"
      assert html =~ "read off this box&#39;s insert commit"
      assert html =~ ~s(<span class="fn">*</span>)
      assert html =~ "it comes with phx.new 1.8.14"
      # A name the project no longer carries is not claimed.
      refute html =~ "gone"
    end

    test "a package from git is its repository: the tag for a version, GitHub for its pages and its releases" do
      base = %{
        "name" => "tailwind",
        "options" => [],
        "requires" => [],
        "offers" => [],
        "base" => true,
        "console" => %{"doors" => [], "tabs" => []},
        "deps" => []
      }

      git = %{
        "url" => "https://github.com/tailwindlabs/heroicons.git",
        "repo" => "tailwindlabs/heroicons",
        "tag" => "v2.2.0",
        "branch" => nil,
        "ref" => nil
      }

      status = %{
        "exists" => true,
        "project" => %{
          "cartridges" => [%{"name" => "tailwind", "installed" => true, "deps" => []}],
          "deps" => [
            %{"name" => "tailwind", "pinned" => "~> 0.3", "locked" => "0.3.1"},
            %{"name" => "heroicons", "pinned" => "v2.2.0", "locked" => "v2.2.0", "git" => git}
          ]
        }
      }

      html =
        render_component(&ConsoleWeb.Box.box/1,
          box: base,
          status: status,
          catalog: [base],
          screen: "box",
          paper: "readme",
          papers: [],
          args: %{},
          packages: %{},
          read_deps: [
            %{name: "tailwind", requirement: "~> 0.3", git: nil, from: "1.8.14"},
            %{
              name: "heroicons",
              requirement: nil,
              git: %{url: git["url"], repo: git["repo"], tag: "v2.2.0", branch: nil, ref: nil},
              from: "1.8.14"
            }
          ],
          now: ~U[2026-09-23 12:00:00Z]
        )

      # The name opens the repository and the tag its tree, with
      # GitHub's mark in place of hex's.
      assert html =~ ~s|href="https://github.com/tailwindlabs/heroicons"|
      assert html =~ ~s|href="https://github.com/tailwindlabs/heroicons/tree/v2.2.0"|
      assert html =~ "icons.svg#github"
      refute html =~ "hex.pm/packages/heroicons"
      # GitHub is asked of it, by the same button, and counts no downloads.
      assert html =~ ~s(phx-value-names="tailwind,heroicons=tailwindlabs/heroicons")
      assert html =~ "GitHub counts no downloads of a repository"
    end

    test "unasked, the column says nothing was read and the button offers to ask" do
      html = with_hex(%{})

      assert html =~ ~s(phx-click="packages_ask")
      assert html =~ ~s(phx-value-names="ex_doc")
      assert html =~ ~s|phx-click="packages_ask"|
      # The name opens the package's own page, with hex's own mark
      # before it — an address, which costs no reading at all.
      assert html =~ ~s|href="https://hex.pm/packages/ex_doc"|
      assert html =~ ~s|src="/images/vendor/hex.svg"|
      # Every fact has a column of its own, and the ones nobody asked
      # for say so rather than standing empty.
      assert html =~
               "the newest stable release — on hex.pm, or on GitHub for a package from there — whatever this project runs"

      assert html =~ ~s|<span class="unlit">–</span>|
    end

    test "read, it says the latest release and how long since" do
      html =
        with_hex(%{
          "ex_doc" => %{
            latest: "0.40.4",
            released_at: "2026-09-03T06:00:00.000000Z",
            downloads: 97_802_365
          }
        })

      assert html =~ "0.40.4"
      assert html =~ "20 days ago"
      assert html =~ "97.8M"
      # The box is not in, so the newest release is only that.
      assert html =~ "hex.pm&#39;s newest release"
      refute html =~ "and the one this project runs"
    end

    test "the newest release says itself against the one the project runs" do
      status = %{
        "exists" => true,
        "project" => %{
          "cartridges" => [
            %{
              "name" => "exdoc",
              "installed" => true,
              "deps" => [
                %{
                  "name" => "ex_doc",
                  "declared" => "~> 0.40",
                  "pinned" => "~> 0.40",
                  "locked" => "0.40.4"
                }
              ]
            }
          ]
        }
      }

      said = %{
        "ex_doc" => %{
          latest: "0.40.4",
          released_at: "2026-09-03T06:00:00.000000Z",
          downloads: 97_802_365
        }
      }

      html =
        render_component(&ConsoleWeb.Box.box/1,
          box: @exdoc_box,
          status: status,
          catalog: [@exdoc_box],
          screen: "box",
          paper: "readme",
          papers: [],
          args: %{},
          packages: said,
          now: ~U[2026-09-23 12:00:00Z]
        )

      assert html =~ "hex.pm&#39;s newest release — and the one this project runs"

      # An older lock reads the other way, naming what the project runs.
      older =
        put_in(status, ["project", "cartridges"], [
          %{
            "name" => "exdoc",
            "installed" => true,
            "deps" => [
              %{
                "name" => "ex_doc",
                "declared" => "~> 0.40",
                "pinned" => "~> 0.40",
                "locked" => "0.38.2"
              }
            ]
          }
        ])

      html =
        render_component(&ConsoleWeb.Box.box/1,
          box: @exdoc_box,
          status: older,
          catalog: [@exdoc_box],
          screen: "box",
          paper: "readme",
          papers: [],
          args: %{},
          packages: said,
          now: ~U[2026-09-23 12:00:00Z]
        )

      assert html =~ "this project runs 0.38.2"
    end

    test "a package hex could not answer for says so, and nothing is blank" do
      html = with_hex(%{"ex_doc" => %{error: "hex.pm has no such package"}})

      assert html =~ "not read"
      assert html =~ "hex.pm has no such package"
    end
  end

  test "with nothing to read the line is the bare verb" do
    # Born with the project, or inserted by a hand that left no commit.
    assert Box.line_argv(@box, %{}, nil, true) == []
  end

  test "a value the project's database does not serve is unlit, and says the state it needs" do
    box = %{
      "name" => "db_admin",
      "options" => [
        %{
          "name" => "admin",
          "type" => "csv",
          "multiple" => true,
          "choices" => [
            %{
              "value" => "pgadmin",
              "requires" => ["ecto"],
              "conditions" => %{"ecto" => %{"database" => "postgres"}}
            },
            %{
              "value" => "phpmyadmin",
              "requires" => ["ecto"],
              "conditions" => %{"ecto" => %{"database" => "mysql"}}
            },
            %{"value" => "adminer", "requires" => [], "conditions" => %{}}
          ]
        }
      ]
    }

    status = %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true},
      "project" => %{
        "cartridges" => [
          %{"name" => "ecto", "installed" => true, "state" => %{"database" => "postgres"}}
        ]
      }
    }

    html = screen(box, status)
    # The need is the cartridge's own mention, a door to its box, with
    # the state it asks beside it: ecto is in, on another database.
    assert html =~ ~r{class="cart-ref in"[^>]*phx-value-name="ecto"}
    assert html =~ "with database mysql"
    refute html =~ "with database postgres"
    assert html =~ "builds on ecto with database mysql, which this project lacks"
  end

  @db_admin %{
    "name" => "db_admin",
    "rerun" => "adds",
    "adds" => ["admin"],
    "requires" => ["ecto"],
    "options" => [
      %{
        "name" => "admin",
        "type" => "csv",
        "multiple" => true,
        "choices" => [
          %{
            "value" => "pgadmin",
            "requires" => ["ecto"],
            "conditions" => %{"ecto" => %{"database" => "postgres"}}
          },
          %{
            "value" => "phpmyadmin",
            "requires" => ["ecto"],
            "conditions" => %{"ecto" => %{"database" => "mysql"}}
          },
          %{"value" => "adminer", "requires" => [], "conditions" => %{}}
        ]
      }
    ]
  }

  defp with_admins(admins) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "project" => %{
        "cartridges" => [
          %{"name" => "ecto", "installed" => true, "state" => %{"database" => "postgres"}},
          %{"name" => "db_admin", "installed" => true, "state" => %{"admin" => admins}}
        ]
      }
    }
  end

  test "what is in is said by the box checked and shut, with no tag beside it" do
    html = screen(@db_admin, with_admins(["pgadmin"]))
    assert html =~ ~r{value="pgadmin"[^>]*checked[^>]*disabled}
    refute html =~ ~s(class="in">in<)
    # The one the database does not serve says why, in its own class —
    # not the need paper's, whose panel it used to borrow.
    assert html =~ ~s(class="line lacks")
    assert html =~ ~s(class="tag lacks")
    refute html =~ ~s(<label class="need")
  end

  # credo's --githook writes into the hook precommit owns.
  @credo %{
    "name" => "credo",
    "rerun" => "adds",
    "adds" => ["githook"],
    "requires" => [],
    "options" => [
      %{
        "name" => "githook",
        "type" => "boolean",
        "default" => false,
        "choices" => nil,
        "requires" => ["precommit"],
        "conditions" => %{}
      }
    ]
  }

  defp with_cartridges(cartridges) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "project" => %{"cartridges" => cartridges}
    }
  end

  test "a switch that builds on a cartridge the project lacks is unlit, and says why" do
    html = screen(@credo, with_cartridges([%{"name" => "precommit", "installed" => false}]))
    assert html =~ ~r{id="opt-githook"[^>]*disabled}
    # On the switch's own line, not beside its flag, and as a mention.
    assert html =~
             ~r{<label[^>]*class="line sw lacks"[^>]*>.*class="tag lacks">needs<.*phx-value-name="precommit"}s

    assert html =~ "builds on precommit, which this project lacks"
  end

  test "with the cartridge in, the switch is lit" do
    html =
      screen(
        @credo,
        with_cartridges([%{"name" => "precommit", "installed" => true, "state" => %{}}])
      )

    refute html =~ ~r{id="opt-githook"[^>]*disabled}
    refute html =~ ~s(class="tag lacks")
  end

  test "a switch turned on names what it builds on" do
    assert ConsoleWeb.Box.value_requires(@credo, %{"githook" => "on"}, %{}) ==
             [{"--githook", ["precommit"], %{}}]

    assert ConsoleWeb.Box.value_requires(@credo, %{"githook" => "off"}, %{}) == []
  end

  test "rerunnable with a value still free: Add to cartridge, lit" do
    html = screen(@db_admin, with_admins(["pgadmin"]))
    assert html =~ "Add to cartridge"
    refute html =~ "nothing left to add"
  end

  test "rerunnable with every value in or out of reach: the add is unlit, and says why" do
    html = screen(@db_admin, with_admins(["pgadmin", "adminer"]))
    assert html =~ "nothing left to add"
    assert html =~ ~r{class="btn primary unlit"}
  end

  test "a need in the specs is the cartridge alone, not the need paper's panel" do
    html =
      render_component(&ConsoleWeb.Box.box/1,
        box: @db_admin,
        status: with_admins(["pgadmin"]),
        catalog: [@db_admin],
        screen: "box",
        paper: "readme",
        papers: [],
        args: %{}
      )

    assert html =~ ~s(class="req")
    refute html =~ ~s(<span class="need")
  end
end
