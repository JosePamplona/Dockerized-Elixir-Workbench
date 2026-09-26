defmodule ConsoleWeb.TabsTest do
  @moduledoc """
  The row of screens, and the pulses on it. A pulse means the same thing
  on every tab that has one: something is happening on that screen right
  now — a job running, a container writing lines, a terminal session open.
  """
  # The bench is one process for the whole console: these drive it.
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  defp status(containers) do
    %{
      "exists" => true,
      "compose_project" => "lorem_ipsum",
      "workspace" => "/w",
      "deployment" => nil,
      "baked" => %{},
      "ports" => %{},
      "git" => %{"repo" => false},
      "containers" => containers
    }
  end

  defp arrives(status) do
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), {:status, {:ok, status}}})
    assert_receive {:bench, :status, _}
  end

  defp logs_tab(html) do
    [tab] = Regex.run(~r{<a[^>]*>\s*Logs.*?</a>}s, html)
    tab
  end

  defp running(service), do: %{"Service" => service, "State" => "running", "Image" => "x:local"}
  defp exited(service), do: %{"Service" => service, "State" => "exited", "Image" => "x:local"}

  test "the Logs pulse follows the containers, not the reader's own follow flag", %{conn: conn} do
    arrives(status([running("app")]))
    {:ok, _view, html} = live(conn, "/deploy")
    assert logs_tab(html) =~ ~s(class="live")

    arrives(status([exited("app")]))
    {:ok, _view, html} = live(conn, "/deploy")
    refute logs_tab(html) =~ ~s(class="live")

    # A container that is not the app writes lines just the same.
    arrives(status([running("database")]))
    {:ok, _view, html} = live(conn, "/deploy")
    assert logs_tab(html) =~ ~s(class="live")
  end

  defp terminal_tab(html) do
    [tab] = Regex.run(~r{<a[^>]*>\s*Terminal.*?</a>}s, html)
    tab
  end

  # A session is a process of the console's, not the page's: the pulse
  # reads from any screen, on a page opened after the session, and goes
  # when the session does — closed, or its process ended.
  test "the Terminal pulse follows the sessions that run", %{conn: conn} do
    arrives(status([running("app")]))
    target = %{name: "app", kind: :app, release: false, oneoff: false, title: "t"}
    Console.Terminals.subscribe()

    {:ok, _view, html} = live(conn, "/deploy")
    refute terminal_tab(html) =~ ~s(class="live")

    {:ok, _} =
      Console.Terminals.open({"app", "bash"},
        exe: System.find_executable("sh"),
        argv: ["-c", "cat"],
        target: target,
        shell: "bash"
      )

    assert_receive {:terminal, {"app", "bash"}, :live}
    {:ok, view, html} = live(conn, "/deploy")
    assert terminal_tab(html) =~ ~s(class="live")
    assert terminal_tab(html) =~ "a session is open"

    Console.Terminals.close({"app", "bash"})
    assert_receive {:terminal, {"app", "bash"}, :closed}
    refute terminal_tab(render(view)) =~ ~s(class="live")

    # A process that ends on its own is no longer a session that runs.
    {:ok, _} =
      Console.Terminals.open({"app", "bash"},
        exe: System.find_executable("sh"),
        argv: ["-c", "exit 0"],
        target: target,
        shell: "bash"
      )

    assert_receive {:terminal, {"app", "bash"}, {:ended, 0}}, 2000
    refute terminal_tab(render(view)) =~ ~s(class="live")
    Console.Terminals.close({"app", "bash"})
  end

  test "the tray's fold is the last job's on the Jobs screen, and back", %{conn: conn} do
    arrives(status([]))
    # A job that waits for a word runs nothing: it is the last job for as long as this takes.
    id = Console.Jobs.run({:delete, nil}, ["delete"], confirm: true)
    # The queue is one for every test: the question must not outlive this one.
    on_exit(fn -> Console.Jobs.cancel(id) end)
    {:ok, view, _html} = live(conn, "/deploy")

    # Opened in the tray, then put away: arriving at Jobs, the job is unfolded.
    render_click(view, "tray_fold", %{})
    render_click(view, "tray_hide", %{})
    html = render_patch(view, "/jobs")
    assert html =~ ~r{class="job open" data-tall="#{id}"}

    # Folded there, the tray is folded on the way back.
    render_click(view, "fold", %{"id" => id})
    html = render_patch(view, "/deploy")
    assert html =~ ~r{<button[^>]*class="bar"[^>]*aria-expanded="false"}
    html = render_patch(view, "/jobs")
    refute html =~ ~r{class="job open" data-tall="#{id}"}
  end

  test "each stack row of the Project card says on its own when the project was born on another",
       %{conn: conn} do
    conf = Console.Config.values(Console.Workbench.config())

    ws = Path.join(System.tmp_dir!(), "claude_probe_born_#{System.unique_integer([:positive])}")
    File.mkdir_p!(ws)
    on_exit(fn -> File.rm_rf!(ws) end)

    # Born on another elixir; the erlang and the debian config names are
    # the ones it was born on.
    File.write!(Path.join(ws, "Dockerfile.local"), """
    ARG ELIXIR="0.0.1"
    ARG    OTP="#{conf["ERLANG_VERSION"]}"
    ARG DEBIAN="#{conf["DEBIAN_VERSION"]}"
    """)

    arrives(%{"exists" => true, "workspace" => ws, "containers" => []})
    {:ok, _view, html} = live(conn, "/deploy")

    [card] = Regex.run(~r{<div[^>]*class="newcard".*?</form>}s, html)
    # The whole card, so the count below sees every stack row.
    assert card =~ "base cartridges"
    assert card =~ "born on 0.0.1"
    # One row moved, one chip: the erlang and the debian rows are quiet.
    assert length(Regex.scan(~r/born on /, card)) == 1
    # The reading of the workspace is on the workspace's own row.
    assert card =~ ~r{workspace</label>.*?existing project}s
  end

  test "the delete is the tab's last box, and no longer the Create foot's neighbour",
       %{conn: conn} do
    arrives(%{
      "exists" => true,
      "workspace" => "/w",
      "compose_project" => "lorem_ipsum",
      "containers" => []
    })

    {:ok, _view, html} = live(conn, "/deploy")

    [card] = Regex.run(~r{<div[^>]*class="newcard".*?</form>}s, html)
    [danger] = Regex.run(~r{<section[^>]*class="danger".*?</section>}s, html)
    [foot] = Regex.run(~r{<div class="foot">.*?</button>\s*</div>}s, html)

    # The card creates and says so; what it cannot undo is not in its foot.
    assert card =~ "New Project"
    assert foot =~ "Create project"
    refute foot =~ "Delete the project"

    # The box says the line and everything it takes, before the button.
    assert danger =~ "Delete the project"
    assert danger =~ "./wb.sh delete"
    assert danger =~ "lorem_ipsum"
    assert danger =~ ~s(phx-value-args="delete")
    refute danger =~ "unlit"
  end

  test "with the workspace empty the delete is unlit, with its reason", %{conn: conn} do
    arrives(%{"exists" => false, "workspace" => "/w", "containers" => []})
    {:ok, _view, html} = live(conn, "/deploy")
    [danger] = Regex.run(~r{<section[^>]*class="danger".*?</section>}s, html)

    assert danger =~ "unlit"
    assert danger =~ "the workspace is empty: nothing to delete"
  end

  test "the picker's line is written from what travelled, not from the button" do
    alias ConsoleWeb.Deploy

    # The row picked and its options, as the form sends them.
    pick = %{target: "scaled", replicas: 6, balancer: false}
    assert Deploy.line("up", pick) == "./wb.sh up --deploy scaled --replicas 6 --no-balancer"

    # Only scaled carries them, and dev names nothing: it is the default.
    assert Deploy.line("up", %{target: "dev", replicas: 6, balancer: false}) ==
             "./wb.sh up --deploy dev"

    assert Deploy.line("up", %{target: "prod", replicas: 6, balancer: false}) ==
             "./wb.sh up --deploy prod"

    # A row's own Bake, whichever row is picked.
    assert Deploy.line("bake dev", pick) == "./wb.sh bake"

    assert Deploy.line("bake scaled", pick) ==
             "./wb.sh bake --deploy scaled --replicas 6 --no-balancer"

    # A row's own Build, the same way: dev names itself, as up does.
    assert Deploy.line("build dev", pick) == "./wb.sh build --deploy dev"

    assert Deploy.line("build scaled", pick) ==
             "./wb.sh build --deploy scaled --replicas 6 --no-balancer"

    # Nothing else runs anything — the foot's bare build went on 2026-09-10.
    assert Deploy.line("build", pick) == nil
    assert Deploy.line("delete", pick) == nil
    assert Deploy.line(nil, pick) == nil
  end

  test "the picker's buttons send the picker, and carry no line of their own", %{conn: conn} do
    arrives(%{"exists" => true, "workspace" => "/w", "containers" => [], "baked" => %{}})
    {:ok, _view, html} = live(conn, "/deploy")

    [sheet] = Regex.run(~r{<section[^>]*class="deployments".*?</section>}s, html)

    assert sheet =~ ~s(<form id="deploy-pick" phx-change="pick" phx-submit="deploy_run">)

    [up] = Regex.run(~r{<button[^>]*value="up"[^>]*>[^<]*Up[^<]*</button>}s, sheet)
    assert up =~ ~s(type="submit")
    assert up =~ ~s(form="deploy-pick")
    assert up =~ ~s(name="do")
    refute up =~ "phx-value-args"

    # Up is the foot's one verb: Build is each row's since 2026-09-11.
    refute sheet =~ ~s(value="build")

    # Each row's Bake and Build say which row it is, and travel the same way.
    for deploy <- ~w(dev prod scaled) do
      assert sheet =~ ~s(value="bake #{deploy}")
      assert sheet =~ ~s(value="build #{deploy}")
    end
  end

  test "the rail's Deployments head says what there is, as its neighbours do", %{conn: conn} do
    head = fn html ->
      [h] =
        Regex.run(~r{Deployments<span class="label">([^<]*)</span>}, html,
          capture: :all_but_first
        )

      String.trim(h)
    end

    arrives(%{"exists" => false, "workspace" => "/w", "containers" => []})
    {:ok, _view, html} = live(conn, "/deploy")
    assert head.(html) == "none baked"

    arrives(%{
      "exists" => true,
      "workspace" => "/w",
      "containers" => [],
      "baked" => %{"dev" => true, "prod" => true},
      "deployment" => "prod"
    })

    {:ok, _view, html} = live(conn, "/deploy")
    assert head.(html) == "2 baked · prod up"

    arrives(%{
      "exists" => true,
      "workspace" => "/w",
      "containers" => [],
      "baked" => %{"dev" => true}
    })

    {:ok, _view, html} = live(conn, "/deploy")
    assert head.(html) == "1 baked · nothing up"
  end

  test "the rail says nothing where it has nothing: the head already said it", %{conn: conn} do
    arrives(%{"exists" => false, "workspace" => "/w", "containers" => []})
    {:ok, _view, html} = live(conn, "/deploy")

    refute html =~ "Nothing answers yet"
    refute html =~ "The workspace is empty: Deploy → Project."
    refute html =~ "phx.new initialises the repository"
    refute html =~ "Nothing inserted yet"
  end

  test "the deployments table is the Deploy tab's, there before any project is", %{conn: conn} do
    arrives(%{"exists" => false, "workspace" => "/w", "containers" => []})
    {:ok, _view, html} = live(conn, "/deploy")

    [sheet] = Regex.run(~r{<section[^>]*class="deployments"[^>]*>.*?</section>}s, html)

    for deploy <- ~w(dev prod scaled) do
      assert sheet =~ ~s(name="target" value="#{deploy}")
    end

    # Three rows, none baked, and every eye and button unlit with the one reason.
    assert length(Regex.scan(~r/>\s*not baked\s*</, sheet)) == 3
    assert length(Regex.scan(~r/class="sq eye unlit"/, sheet)) == 4
    assert sheet =~ "the workspace is empty: Deploy → Project creates one"
    refute sheet =~ ~s(class="sq eye")

    # The fourth is the scaled row's own: the cluster reads under it,
    # unlit while that deployment is not up.
    assert sheet =~ "the replicas as nodes"
    assert sheet =~ "scaled is not up: Up it, under the table, and its replicas read here"
    refute sheet =~ ~s(href="/deploy?cluster=1")
  end

  # The Cluster tab was retired on 2026-09-25: the replicas as nodes,
  # and the two probes that only they can answer, read in a box under
  # the scaled row — where the reader just pressed Up.
  test "the cluster reads under the scaled row, opened by its own square", %{conn: conn} do
    arrives(
      status([running("app1"), running("app2"), running("balancer")])
      |> Map.merge(%{
        "deployment" => "scaled",
        "baked" => %{"scaled" => true},
        "ports" => %{"app" => 4001},
        "addresses" => %{"app1" => "172.18.0.3", "app2" => "172.18.0.4"},
        "project" => %{"app" => "lorem_ipsum"}
      })
    )

    {:ok, view, html} = live(conn, "/deploy")

    # Closed, the square is lit and says where it goes; no box yet.
    assert html =~ ~s(href="/deploy?cluster=1")
    refute html =~ "Who is connected?"

    html = view |> element(~s(a[href="/deploy?cluster=1"])) |> render_click()

    # The replicas as nodes, and the two probes.
    assert html =~ "2 replicas"
    assert html =~ "balancer on :4001"
    assert html =~ "172.18.0.3"
    assert html =~ "lorem_ipsum@172.18.0.4"
    assert html =~ "Who answers?"
    assert html =~ "Who is connected?"

    # Pressed again it closes, and a file's eye closes it too: one box at
    # a time under the table.
    assert html =~ ~s(aria-pressed="true")
    refute render_patch(view, "/deploy?compose=scaled") =~ "Who is connected?"
    refute render_patch(view, "/deploy") =~ "Who is connected?"
  end

  # Stop and Down came off the rows on 2026-09-26: only one deployment is
  # up at a time, so at most one row's Stop was ever lit, and `down`
  # clears the whole project — orphans of the other deployments included
  # — so it never acted on the row it sat in. At the foot they name what
  # they act on, since Up there is the row picked and these are not.
  test "Stop and Down stand at the foot of the sheet, naming what is up", %{conn: conn} do
    arrives(
      status([running("app1"), running("balancer")])
      |> Map.merge(%{"deployment" => "scaled", "baked" => %{"scaled" => true}})
    )

    {:ok, _view, html} = live(conn, "/deploy")
    [sheet] = Regex.run(~r{<section[^>]*class="deployments"[^>]*>.*?</section>}s, html)
    [foot] = Regex.run(~r{<div class="foot">.*?</div>\s*</section>}s, sheet <> "</section>")

    assert foot =~ "Stop scaled"
    assert foot =~ "Down scaled"

    # And the rows keep only what is theirs: one file, one image each.
    [rows] = Regex.run(~r{<tbody>.*?</tbody>}s, sheet)
    assert rows =~ ">Bake<"
    assert rows =~ ">Build<"
    refute rows =~ ">Stop<"
    refute rows =~ ">Down<"
  end

  # One vocabulary for a state, in one element: the Containers table wore
  # a `.chip` and a service's plate a `.read`, off the same function
  # (`Cartridges.container_reading/1`), so the reader met the same words
  # in two faces. Since 2026-09-26 both are `.read` — and Docker's own
  # line, which only the chip carried, comes with it.
  test "the rail reads a container's state in the element a service's plate wears", %{conn: conn} do
    arrives(
      status([
        %{
          "Service" => "app",
          "State" => "running",
          "Health" => "healthy",
          "Image" => "x:local",
          "Status" => "Up 2 hours (healthy)"
        },
        %{"Service" => "migrate", "State" => "exited", "ExitCode" => 1, "Image" => "x:local"}
      ])
    )

    {:ok, _view, html} = live(conn, "/deploy")
    [table] = Regex.run(~r{<table[^>]*id="containers".*?</table>}s, html)

    assert table =~ ~s(class="read good")
    assert table =~ ">healthy<"
    assert table =~ ~s(class="read bad")
    assert table =~ ">exited 1<"
    assert table =~ ~s|title="Up 2 hours (healthy)"|

    # And no chip left in it: the two faces were the whole point.
    refute table =~ "chip"
  end

  test "the Docker screen is lit before any project is, and opens on its containers", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/docker")
    [tab] = Regex.run(~r{<a[^>]*>\s*Docker.*?</a>}s, html)
    assert tab =~ ~s(aria-selected="true")
    [doc] = Regex.run(~r{<a[^>]*href="/docker\?doc=containers"[^>]*>}, html)
    assert doc =~ ~s(aria-selected="true")
    assert html =~ "The daemon"
  end

  test "there is no Git tab: its two papers are the Project's, unlit without a repository", %{
    conn: conn
  } do
    arrives(status([]))
    {:ok, _view, html} = live(conn, "/project")
    refute Regex.match?(~r{<(a|button)[^>]*>\s*Git\s*</(a|button)>}s, html)

    for paper <- ["Changes", "History"] do
      [tab] = Regex.run(~r{<button[^>]*>\s*#{paper}.*?</button>}s, html)
      assert tab =~ ~s(aria-disabled="true") and tab =~ "no repository"
    end
  end

  test "no containers at all is no pulse", %{conn: conn} do
    arrives(status([]))
    {:ok, _view, html} = live(conn, "/deploy")
    refute logs_tab(html) =~ ~s(class="live")
  end
end
