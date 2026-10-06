defmodule ConsoleWeb.BackTest do
  @moduledoc """
  A box, or the workbench drawer, opens over the screen the reader is
  on, and the screen keeps its place under it: on Project, the paper
  and the commit open on it. Put back and Close come back to that place.
  """
  # The bench is one process for the whole console: these drive it.
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  defp status do
    %{
      "exists" => true,
      "compose_project" => "lorem_ipsum",
      "workspace" => "/w",
      "deployment" => nil,
      "baked" => %{},
      "ports" => %{},
      "git" => %{
        "repo" => true,
        "clean" => true,
        "head" => "abc1234",
        "identity" => "The Workbench <wb@example>",
        "inserts" => []
      },
      "containers" => [],
      "project" => %{"cartridges" => []}
    }
  end

  defp k6 do
    %{
      "name" => "k6",
      "summary" => "What k6 is",
      "pending" => false,
      "base" => false,
      "collection" => false,
      "covers" => %{"front" => nil},
      "options" => [],
      "requires" => [],
      "version" => nil
    }
  end

  defp arrives(reading) do
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), reading})
    assert_receive {:bench, _, _}
  end

  setup do
    arrives({:status, {:ok, status()}})
    arrives({:catalog, {:ok, [k6()]}})
    :ok
  end

  test "a cartridge pressed on History opens its box over History, and Put back returns there",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history&commit=abc1234")

    render_click(view, "open", %{"name" => "k6"})
    assert_patch(view, "/project?paper=history&commit=abc1234&box=k6")

    html = render(view)
    assert html =~ ~s(aria-label="The box in hand")
    assert html =~ ~s(href="/project?paper=history&amp;commit=abc1234")

    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history&commit=abc1234")
  end

  test "the box's manual names its paper in the same key, and History stays under it",
       %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history&commit=abc1234")

    render_click(view, "open", %{"name" => "k6"})
    assert_patch(view, "/project?paper=history&commit=abc1234&box=k6")

    # The ribbon's Manual link names the box's paper; the project's is left out of the URL, not overwritten.
    view
    |> element(~s(a[href="/project?commit=abc1234&box=k6&screen=manual&paper=readme"]))
    |> render_click()

    assert_patch(view, "/project?commit=abc1234&box=k6&screen=manual&paper=readme")

    # Put back still goes to History with its commit: the paper under the box was never readme.
    html = render(view)
    assert html =~ ~s(href="/project?paper=history&amp;commit=abc1234")
    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history&commit=abc1234")
  end

  # Inside a box, the manual keeps its paper across the box's other
  # screens: Installation's link names no paper, and the Manual link
  # carries the one the box was on.
  test "a box's manual keeps its paper across Installation", %{conn: conn} do
    {:ok, view, _} = live(conn, "/shelf?box=k6&screen=manual&paper=changelog")
    assert render(view) =~ ~s(href="/shelf?box=k6&amp;screen=manual&amp;paper=changelog")

    view |> element(~s(a[href="/shelf?box=k6&screen=install"])) |> render_click()
    assert_patch(view, "/shelf?box=k6&screen=install")
    html = render(view)
    assert html =~ ~s(href="/shelf?box=k6&amp;screen=manual&amp;paper=changelog")
    refute html =~ ~s(href="/shelf?box=k6&amp;screen=manual&amp;paper=readme")

    # Another box picked up starts on its first paper.
    render_click(view, "close", %{})
    {:ok, view, _} = live(conn, "/shelf?box=k6&screen=manual")
    assert render(view) =~ ~r{aria-selected="true"[^>]*>\s*README}
  end

  test "a cartridge pressed in the workbench README opens over it, and Close leaves the README",
       %{conn: conn} do
    {:ok, view, html} = live(conn, "/deploy?wb=manual&paper=changelog")
    render_patch(view, "/deploy?wb=manual&paper=readme")

    assert html =~ "wb-booklet"
    html = render(view)

    assert html =~
             ~r{<a href="\?box=k6&amp;screen=manual&amp;paper=changelog" data-patch[^>]*>CHANGELOG</a>}

    # What the link's click sends (the Booklet hook): the box over the
    # drawer, which stays in the address under it.
    render_hook(view, "goto", %{"href" => "?box=k6&screen=manual&paper=changelog"})
    assert_patch(view, "/deploy?wb=manual&box=k6&screen=manual&paper=changelog")

    # Both on the page: the README as it was — `paper` is the box's now,
    # and the drawer did not turn to its own changelog — out of reach
    # under the box, and the box's Manual on its paper.
    html = render(view)
    assert html =~ ~r{<aside[^>]*aria-label="The workbench"[^>]*inert}
    assert html =~ ~s(aria-label="The box in hand")
    assert html =~ ~s(id="wb-booklet") and html =~ ~s(id="d-booklet")
    assert html =~ "Two words are used through the rest of this document."

    # The box's own links keep the drawer under it: another screen of
    # the box, and Put back, which leaves the README.
    assert html =~ ~s(href="/deploy?wb=manual&amp;box=k6&amp;screen=install")
    assert html =~ ~r{<a[^>]*href="/deploy\?wb=manual"[^>]*>\s*Put back}

    render_click(view, "close", %{})
    assert_patch(view, "/deploy?wb=manual")

    html = render(view)
    refute html =~ ~s(aria-label="The box in hand")
    refute html =~ ~r{<aside[^>]*aria-label="The workbench"[^>]*inert}
    assert html =~ "Two words are used through the rest of this document."

    # Closed again: the screen.
    render_click(view, "close", %{})
    assert_patch(view, "/deploy")
  end

  test "a cartridge pressed in another's paper leaves a trail: ‹ goes back one, Put back puts it all away",
       %{conn: conn} do
    arrives({:catalog, {:ok, [k6(), Map.put(k6(), "name", "monitoring")]}})
    back = ~r{<a[^>]*class="btn back"}

    {:ok, view, html} = live(conn, "/shelf?box=k6&screen=manual&paper=changelog")
    assert html =~ ~r{<a[^>]*href="/shelf"[^>]*>\s*Put back}

    # Opened from no other box: nothing behind it, and no ‹.
    refute html =~ back

    # A link in k6's paper to monitoring's: k6 is left on the trail, on
    # the screen and the paper it was on.
    render_hook(view, "goto", %{"href" => "?box=monitoring&screen=manual&paper=readme"})

    assert_patch(
      view,
      "/shelf?box=monitoring&screen=manual&paper=readme&from=k6.manual.changelog"
    )

    html = render(view)
    assert html =~ ~s(<h3>monitoring</h3>)

    # ‹ goes back one box, to the paper it was left on; Put back goes to
    # the screen whatever the trail; the box's own links keep the trail.
    assert [step] = Regex.run(~r{<a[^>]*class="btn back"[^>]*>.*?</a>}s, html)
    assert step =~ ~s(href="/shelf?box=k6&amp;screen=manual&amp;paper=changelog")
    assert step =~ ~s(<use href="/images/icons.svg#back")
    assert step =~ ~r{<span[^>]*class="sr"[^>]*>\s*Back to k6\s*</span>}

    assert html =~ ~r{<a[^>]*href="/shelf"[^>]*>\s*Put back}

    assert html =~
             ~s(href="/shelf?from=k6.manual.changelog&amp;box=monitoring&amp;screen=install")

    # Turning a paper of the box in hand adds nothing to the trail.
    render_hook(view, "goto", %{"href" => "?box=monitoring&screen=manual&paper=changelog"})

    assert_patch(
      view,
      "/shelf?box=monitoring&screen=manual&paper=changelog&from=k6.manual.changelog"
    )

    # ‹ pressed: k6 again, on its changelog, with nothing behind it.
    html = render_patch(view, "/shelf?box=k6&screen=manual&paper=changelog")
    assert html =~ ~s(<h3>k6</h3>)
    assert html =~ ~r{aria-selected="true"[^>]*>\s*Changelog}
    refute html =~ back
  end

  test "Close puts the box away whole, however many boxes led to it", %{conn: conn} do
    arrives({:catalog, {:ok, [k6(), Map.put(k6(), "name", "monitoring")]}})

    {:ok, view, _} =
      live(conn, "/shelf?box=monitoring&screen=manual&paper=readme&from=k6.manual.changelog")

    render_click(view, "close", %{})
    assert_patch(view, "/shelf")
  end

  test "a trail that does not read as boxes is not followed", %{conn: conn} do
    {:ok, view, _} = live(conn, "/shelf?box=k6&screen=manual&from=../etc,k6,<x>.manual.readme")
    html = render(view)
    assert html =~ ~r{<a[^>]*href="/shelf"[^>]*>\s*Put back}
    refute html =~ ~s(class="btn back")
  end

  test "a box alone closes onto the screen, as before", %{conn: conn} do
    {:ok, view, _} = live(conn, "/shelf?box=k6&screen=manual")
    render_click(view, "close", %{})
    assert_patch(view, "/shelf")
  end

  test "the workbench drawer's manual keeps its paper across Config", %{conn: conn} do
    {:ok, view, _} = live(conn, "/deploy?wb=manual&paper=changelog")
    html = render_patch(view, "/deploy?wb=config")
    assert html =~ ~s(href="/deploy?wb=manual&amp;paper=changelog")
    refute html =~ ~s(href="/deploy?wb=manual&amp;paper=readme")
  end

  test "the workbench drawer's Interface keeps its part across Config, and names it on the ribbon",
       %{conn: conn} do
    {:ok, view, html} = live(conn, "/deploy?wb=ui&part=terminal")
    assert html =~ ~s(data-part="terminal")

    # The ribbon: Overlay, Terminal, Code, Credits — a theme a surface; Text retired for now.
    for part <- ~w(overlay code credits) do
      assert html =~ ~r{href="/deploy\?wb=ui&amp;part=#{part}"[^>]*aria-selected="false"}
    end

    refute html =~ ~s(part=text")
    refute html =~ ~s(part=files")

    # Each theme part: its shelf first, a card a theme and Custom hidden,
    # then the one fold, Adjustments. The suite's shelf
    # has a probe on each.
    assert html =~
             ~r{data-shelf="terminal"[^>]*>.*?data-theme-key="probe"[^>]*title="The suite · MIT"}s

    assert html =~ ~r{data-shelf="code"[^>]*>.*?data-theme-key="probe"}s
    assert html =~ ~r{data-theme-key="custom"[^>]*hidden}

    assert html =~
             ~r{<span>Adjustments</span><span class="touch"></span><button[^>]*class="sq small foldsq"[^>]*aria-expanded="false"}

    # Its groups: Font; the terminal's colour tables, each a pairs table
    # of two; the code's sheet, diff and languages, the language a native
    # select ending with Other.
    assert html =~ ~r{<h6>Font</h6>}
    assert html =~ ~r{data-term="ansi"[^>]*data-pairs="2"}
    assert html =~ ~r{data-sheet="sheet"[^>]*data-pairs="2"}
    assert html =~ ~r{data-diff="diff"[^>]*data-pairs="2"}

    assert html =~
             ~r{<select id="colours-lang"[^>]*>\s*<option value="elixir" selected[^>]*>\s*Elixir}

    assert html =~ ~r{<option value="shell"[^>]*>\s*Shell}

    # And Other, a file with no language, read in the sheet's foreground.
    assert html =~ ~r{<option value="other"[^>]*>\s*Other\s*</option>\s*</select>}
    assert html =~ ~r{class="f open sample" data-lang="other" hidden}
    refute html =~ "lmark"

    # The miniature's ground cell is a control, as the band's is.
    assert html =~
             ~r{<button[^>]*class="mground"[^>]*>\s*<svg[^>]*><use href="/images/icons.svg#ground"}

    # Download Current and Load Custom are dev's: the suite runs without them.
    refute html =~ "Download Current"
    refute html =~ "data-theme-download"
    refute html =~ "data-theme-file"

    # Clear Custom is anyone's, one a part, and stays away until the hook
    # finds a Custom to clear.
    assert length(
             Regex.scan(~r{<button[^>]*data-theme-clear[^>]*hidden[^>]*>\s*Clear Custom}, html)
           ) ==
             2

    # The hook is handed the shelves as JSON, kind and all.
    assert html =~ ~s(<script type="application/json" id="themes">)
    assert html =~ "terminal.foreground"
    assert html =~ ~s("kind":"code")

    # Credits: one ficha for faces and themes — the name (a face set in
    # itself), whose and under which licence as chips, the site with the
    # house's mention (GitHub's mark and owner/repo, or the globe and the
    # host), what it draws — in three groups with the small fold square.
    assert html =~
             ~r{<span>Terminal themes</span><button[^>]*class="sq small foldsq"[^>]*aria-expanded="true"}

    assert html =~ ~r{<span>Code themes</span>}
    assert html =~ ~r{<span>Faces</span>}

    for kind <- ~w(terminal code) do
      assert html =~
               ~r{<section[^>]*data-kind="#{kind}"[^>]*data-theme="probe"|<section[^>]*data-theme="probe"[^>]*data-kind="#{kind}"}
    end

    assert html =~
             ~r{class="site-ref ?" href="https://example.test/probe"[^>]*title="Probe&#39;s site: example.test"><svg[^>]*class="mark"[^>]*><use href="/images/icons.svg#globe"></use></svg>example.test</a>}

    assert html =~ ~r{class="spec" style="font-family:&#39;Tamzen10x20&#39;[^"]*">Tamzen</span>}
    assert html =~ "Suraj N. Kurapati, after Tamsyn by Scott Fial"

    assert html =~
             ~r{class="site-ref ?" href="https://github.com/sunaku/tamzen-font"[^>]*><img[^>]*class="mark light"[^>]*src="/images/vendor/github.svg"[^>]*><img[^>]*class="mark dark"[^>]*src="/images/vendor/github-white.svg"[^>]*>sunaku/tamzen-font</a>}

    assert html =~
             ~r{class="spec" style="font-family:&#39;Greybeard11x22&#39;[^"]*">Greybeard</span>}

    assert html =~ "Andy Walker, after UW ttyp0 by Uwe Waldmann"

    assert html =~
             ~r{class="site-ref ?" href="https://github.com/jpt/barlow"[^>]*>.*?jpt/barlow</a>}s

    # A theme's ficha says what it draws, read off its file: the probe carries both grounds.
    assert html =~ "The terminal&#39;s colours, both grounds."
    # A theme that says what it is (dew.theme.about) is credited in its own words.
    assert html =~ "The probe&#39;s code, as the suite wrote it."
    refute html =~ "The sheet, every language&#39;s palette and the diff&#39;s, both grounds."
    # The theme in force is the hook's to mark: nothing is, server-side.
    assert html =~ ~r{<p[^>]*class="on" hidden}
    refute html =~ "In use"

    html = render_patch(view, "/deploy?wb=config")
    assert html =~ ~s(href="/deploy?wb=ui&amp;part=terminal")
    refute html =~ ~s(href="/deploy?wb=ui&amp;part=overlay")

    # A part the URL names that is not one is the first.
    {:ok, _view, html} = live(conn, "/deploy?wb=ui&part=nope")
    assert html =~ ~s(data-part="overlay")
  end

  test "the workbench drawer opens over the paper and Close comes back to it", %{conn: conn} do
    {:ok, view, _} = live(conn, "/project?paper=history")

    view |> element(~s(a[href="/project?paper=history&wb=config"])) |> render_click()
    assert_patch(view, "/project?paper=history&wb=config")

    # The ribbon's Manual names `paper` for the workbench, once; History stays under it.
    [manual] =
      Regex.run(~r{href="(/project\?wb=manual&amp;paper=[^"]+)"}, render(view),
        capture: :all_but_first
      )

    manual = String.replace(manual, "&amp;", "&")
    view |> element(~s(a[href="#{manual}"])) |> render_click()
    assert_patch(view, manual)

    html = render(view)
    assert html =~ ~s(href="/project?paper=history")
    render_click(view, "close", %{})
    assert_patch(view, "/project?paper=history")
  end
end
