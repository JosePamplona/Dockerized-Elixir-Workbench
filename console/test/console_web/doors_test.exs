defmodule ConsoleWeb.DoorsTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Doors

  # A status with ash (with ash_oban), rest and healthcheck in, and graphql
  # not; a catalog with each one's console block.
  @status %{
    "ports" => %{"app" => 4000, "pgadmin" => 5050},
    "deployment" => "dev",
    "project" => %{
      "cartridges" => [
        %{"name" => "ash", "installed" => true, "state" => %{"with" => ["ash_oban"]}},
        %{"name" => "rest", "installed" => true},
        %{"name" => "healthcheck", "installed" => true, "state" => %{"endpoint" => "/healthz"}},
        %{"name" => "graphql", "installed" => false}
      ]
    }
  }
  @catalog [
    %{
      "name" => "ash",
      "console" => %{
        "doors" => [%{"label" => "admin", "path" => "/admin", "when" => %{"with" => "ash_admin"}}]
      }
    },
    %{
      "name" => "rest",
      "console" => %{
        "doors" => [
          %{"label" => "swagger", "path" => "/dev/swagger"},
          %{"label" => "openapi", "path" => "/dev/openapi"}
        ]
      }
    },
    %{
      "name" => "healthcheck",
      "console" => %{"probes" => [%{"label" => "health", "path" => "{endpoint}"}]}
    },
    %{
      "name" => "graphql",
      "console" => %{"doors" => [%{"label" => "graphiql", "path" => "/graphiql"}]}
    },
    %{
      "name" => "coveralls",
      "console" => %{
        "doors" => [
          %{
            "label" => "coverage",
            "path" => "/dev/docs/cover",
            "when" => %{"cartridge" => "exdoc"}
          }
        ]
      }
    }
  ]

  test "the plan sorts every door by what keeps it shut" do
    page = Doors.page(@status, @catalog)

    assert page.up and page.port == 4000 and page.deployment == "dev"
    assert Enum.map(page.own, & &1.href) == ["http://localhost:4000", "http://localhost:5050"]

    assert Enum.map(page.open, &{&1.label, &1.href, &1.who}) == [
             {"swagger", "http://localhost:4000/dev/swagger", "rest"},
             {"openapi", "http://localhost:4000/dev/openapi", "rest"}
           ]

    assert [%{label: "admin", why: "only with --with ash_admin", href: false, who: "ash"}] =
             page.shut

    assert [%{label: "health", path: "/healthz", href: "http://localhost:4000/healthz"}] =
             page.probes

    assert Enum.map(page.waiting, &{&1.label, &1.why}) == [
             {"graphiql", "insert graphql first"},
             {"coverage", "insert coveralls first"}
           ]

    assert Doors.hrefs(page) == [
             "http://localhost:4000",
             "http://localhost:5050",
             "http://localhost:4000/dev/swagger",
             "http://localhost:4000/dev/openapi",
             "http://localhost:4000/healthz"
           ]
  end

  test "with nothing up every door is shut by that, and nothing is called" do
    page = Doors.page(Map.put(@status, "deployment", nil), @catalog)

    refute page.up
    assert page.open == []

    assert Enum.map(page.shut, & &1.why) == [
             "only with --with ash_admin",
             "the app is down",
             "the app is down"
           ]

    assert [%{href: false}] = page.probes
    assert Enum.map(page.own, & &1.href) == [false, false]
    assert Doors.hrefs(page) == []
  end

  test "no status, no plan" do
    assert Doors.page(nil, @catalog) == nil
  end
end
