defmodule ConsoleWeb.ProjectScreenTest do
  @moduledoc """
  The Mix paper: what `def project` says, then every package the
  project carries — the Box's own table, without the column of what a
  box asks for, since here there is only the project.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "Mix draws def project in a code box and every package, with who brought it" do
    status = %{
      "exists" => true,
      "project" => %{
        "deps" => [
          %{"name" => "phoenix", "pinned" => "~> 1.8.0", "locked" => "1.8.14"},
          %{"name" => "swoosh", "pinned" => "~> 1.15", "locked" => "1.15.3"},
          %{
            "name" => "heroicons",
            "pinned" => "v2.2.0",
            "locked" => "v2.2.0",
            "git" => %{
              "url" => "https://github.com/tailwindlabs/heroicons.git",
              "repo" => "tailwindlabs/heroicons",
              "tag" => "v2.2.0",
              "branch" => nil,
              "ref" => nil
            }
          }
        ]
      }
    }

    html =
      render_component(&ConsoleWeb.ProjectScreen.project_screen/1,
        carried: ~w(mix),
        paper: "mix",
        page: %{
          mix: %{
            spec: [
              {"app", ~s(<span class="ss">:lorem</span>)},
              {"start_permanent", ~s(<span class="ss">:prod</span>)}
            ],
            options: %{"heroicons" => "app: false,\ndepth: 1"}
          }
        },
        status: status,
        hex: %{},
        by: %{
          "phoenix" => %{"by" => :born},
          "swoosh" => %{"by" => {:boxes, ["mailer"]}, "declared" => "~> 1.16"},
          "heroicons" => %{"by" => {:boxes, ["tailwind"]}, "declared" => nil, "read" => true}
        }
      )

    # def project in a code box, as Docker sets the daemon's lines: the
    # key, and the value coloured as Elixir.
    assert html =~ ~s(<code class="code-box spec">)
    assert html =~ ~s(<span class="k">start_permanent</span>)
    assert html =~ ~r|class="v src"\s+data-lang="elixir"\s*><span class="ss">:prod</span>|
    # Who brought each, last, and its options.
    assert html =~ "brought by"
    assert html =~ ~s(phx-value-name="mailer")
    assert html =~ ~s(phx-value-name="tailwind")
    assert html =~ "born with it"
    # The options as mix.exs writes them, uncoloured.
    assert html =~ ~s(<td class="opts">app: false,\ndepth: 1</td>)
    # The cartridge's version, and mix.exs marked where it pins another:
    # swoosh only — phoenix was born with the project, nothing asks.
    assert html =~ "~&gt; 1.16"
    assert length(Regex.scan(~r/class="asks warn"/, html)) == 1
    assert html =~ "where the cartridge brings ~&gt; 1.16"
    # A base box's version read off its insert carries the mark.
    assert html =~ ~s(<span class="fn">*</span>)
    assert html =~ ~s|href="https://hexdocs.pm/phoenix/1.8.14"|
    assert html =~ ~s|href="https://github.com/tailwindlabs/heroicons/tree/v2.2.0"|
    # Hex is asked of what it has, GitHub of its repositories.
    assert html =~ ~s(phx-value-names="phoenix,swoosh,heroicons=tailwindlabs/heroicons")
  end
end
