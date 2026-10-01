defmodule Console.HighlightSampleTest do
  use ExUnit.Case, async: true

  alias Console.Highlight

  # Each language's sample touches the classes its palette names: what the
  # Interface tab shows is every rule the reader can set, not a few.
  @classes %{
    elixir: ~w(k nc na kn s ss mi nf o sr p c1),
    html: ~w(nt na p n o mi),
    css: ~w(nc no kc mi mf kt nf s c p o),
    json: ~w(nt s2 mi kc p),
    ts: ~w(kr kd kt nf o mi s si c1 p),
    markdown: ~w(gh gs ge g p kc),
    godot: ~w(k ni kd kt nv nf o mf mi s2 p c1),
    shell: ~w(k kd nf nv o s2 s1 mi p c1)
  }

  test "a fence is coloured by the name it opens with, or left plain" do
    assert {:ok, :elixir, html} = Highlight.fenced("elixir", "def a, do: :ok")
    assert html =~ ~s(class="kd") and html =~ ~s(class="ss")
    assert {:ok, :shell, html} = Highlight.fenced("sh", "mix test | grep ok")
    assert html =~ ~s(class="nf") and html =~ ~s(class="o")
    assert {:ok, :shell, _} = Highlight.fenced("bash", "ls")
    assert {:ok, :html, _} = Highlight.fenced("HEEx title=\"x\"", "<p>{@a}</p>")
    assert Highlight.fenced("", "x") == :plain
    assert Highlight.fenced("text", "x") == :plain
    assert Highlight.fenced("jsonc", "// c\n{}") == :plain
  end

  test "every language's sample touches every rule of its palette" do
    for lang <- Highlight.languages(), class <- @classes[lang] do
      assert Highlight.sample(lang) =~ ~s(class="#{class}"), "no #{class} in the #{lang} sample"
    end
  end

  test "Other is a file with no language, plain, with its changed line" do
    assert Highlight.samples() == Highlight.languages() ++ [:other]
    assert Highlight.sample(:other) =~ "name = &quot;lobby&quot;"
    refute Highlight.sample(:other) =~ "class="

    assert [
             {:hunk, _, _, _, _},
             _,
             _,
             {:del, 3, nil, "−", "max = 8"},
             {:add, nil, 3, "+", "max = 12"} | _
           ] =
             Highlight.sample_diff(:other)
  end

  test "a file's language is its palette's name" do
    assert Highlight.lang("lib/a.ex") == :elixir
    assert Highlight.lang("lib/a.html.heex") == :html
    assert Highlight.lang("assets/css/app.css") == :css
    assert Highlight.lang("assets/css/_band.scss") == :css
    assert Highlight.lang("player.gd") == :godot
    assert Highlight.lang("tint.gdshader") == :godot
    assert Highlight.lang("scenes/Player.tscn") == :godot
    assert Highlight.lang("project.godot") == :godot
    assert Highlight.lang("assets/js/app.js") == :ts
    assert Highlight.lang("assets/ts/app.ts") == :ts
    assert Highlight.lang("config.json") == :json
    assert Highlight.lang("README.md") == :markdown
    assert Highlight.lang("logo.png") == nil
    assert Highlight.lang("a.toml") == nil
  end

  test "a lexer with options lexes lines like any other" do
    assert {:lexer, [first | _]} = Highlight.lines("README.md", "# Title\n\ntext\n")
    assert first =~ ~s(class="gh")
  end
end
