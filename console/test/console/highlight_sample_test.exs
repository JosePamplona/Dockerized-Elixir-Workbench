defmodule Console.HighlightSampleTest do
  use ExUnit.Case, async: true

  alias Console.Highlight

  # Each language's sample touches the classes its palette names: what the
  # Interface tab shows is every rule the reader can set, not a few.
  @classes %{
    elixir: ~w(k nc na kn ow s ss sa sd nd ni nv mi nf o sr p c c1),
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

  # Makeup's lexer and the grammar VS Code reads Elixir with sort a few
  # tokens apart, and the palette is a theme written against the grammar
  # (Console.Highlight.ElixirTokens). Spaces and bracket pairs are cut
  # from the HTML so a line reads as its classes.
  defp classes(source) do
    {:ok, :elixir, html} = Highlight.fenced("elixir", source)

    html
    |> String.replace(~r/ data-group-id="[^"]*"/, "")
    |> String.replace(~r/<span class="w">(\s*)<\/span>/, "\\1")
    |> String.replace(~r/<span class="([^"]*)">/, "‹\\1›")
    |> String.replace("</span>", "")
    |> String.replace("&quot;", ~s("))
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.trim()
  end

  describe "Elixir's tokens, sorted as its editor's grammar sorts them" do
    test "a comma, a fat arrow and a binary's brackets are operators" do
      assert classes(~S(%{"k" => [a, b]})) == ~S(‹p›%{‹s›"k" ‹o›=> ‹p›[‹n›a‹o›, ‹n›b‹p›]‹p›})
      assert classes("<<a::8>>") == "‹o›<<‹n›a‹o›::‹mi›8‹o›>>"
    end

    test "the colon and the quotes of an atom or a keyword are the constant's mark" do
      assert classes("[:ok, at: 1]") == "‹p›[‹sa›:‹ss›ok‹o›, ‹ss›at‹sa›: ‹mi›1‹p›]"
      assert classes(~S(:"a b")) == ~S(‹sa›:"‹ss›a b‹sa›")
      assert classes(~S("a b": 1)) == ~S(‹sa›"‹ss›a b‹sa›"‹sa›: ‹mi›1)
      # A colon inside the quotes is the atom's text, and a hole is code.
      assert classes(~S(:"x\n:y#{a, b}z")) ==
               ~S(‹sa›:"‹ss›x‹se›\n‹ss›:y‹si›#{‹n›a‹o›, ‹n›b‹si›}‹ss›z‹sa›")
    end

    test "an Erlang module is an atom, and a module's dots are separators" do
      assert classes(":erlang.now()") == "‹sa›:‹ss›erlang‹o›.‹n›now‹p›(‹p›)"
      assert classes("Foo.Bar.baz") == "‹nc›Foo‹o›.‹nc›Bar‹o›.‹n›baz"
      # ... but the name a module is defined with is one name.
      assert classes("defmodule Foo.Bar do") == "‹kd›defmodule ‹nc›Foo.Bar ‹k›do"
    end

    test "a capture's & is a variable's mark, its place a keyword" do
      assert classes("&(&1 + 1)") == "‹nd›&‹p›(‹nd›&‹ni›1 ‹o›+ ‹mi›1‹p›)"
      assert classes("&Mod.fun/1") == "‹nd›&‹nc›Mod‹o›.‹n›fun‹o›/‹mi›1"
    end

    test "the wildcard is a comment, a character a number, a charlist neither" do
      assert classes("{_, ?a, 'bc'}") == "‹p›{‹c›_‹o›, ‹mi›?a‹o›, ‹sc›'bc'‹p›}"
      assert classes("__MODULE__") == "‹bp›__MODULE__"
    end

    test "a word list's delimiters are brackets, with what trails the last" do
      assert classes("~w(a b)a") == "‹p›~w(‹sx›a b‹p›)a"
      assert classes(~S(~w[a #{x} b])) == ~S(‹p›~w[‹sx›a ‹si›#{‹n›x‹si›}‹sx› b‹p›])
      assert classes("~W|a b|") == "‹p›~W|‹sx›a b‹p›|"
      assert classes("~w()") == "‹p›~w(‹p›)"
      # Any other sigil is left whole.
      assert classes("~s(a b)") == "‹s›~s(a b)"
    end

    test "a name in a def's head is a parameter, up to the bracket that closes it" do
      assert classes(~S"def f(a, %{k: v} = m, _u, o \\ g(1)) when a > 1, do: a") ==
               ~S"‹kd›def ‹nf›f‹p›(‹nv›a‹o›, ‹p›%{‹ss›k‹sa›: ‹nv›v‹p›} ‹o›= ‹nv›m‹o›, ‹c›_u‹o›, " <>
                 ~S"‹nv›o ‹o›\\ ‹nv›g‹p›(‹mi›1‹p›)‹p›) ‹ow›when ‹n›a ‹o›> ‹mi›1‹o›, ‹ss›do‹sa›: ‹n›a"

      # A guard's and a delegate's are not heads to the grammar; nor is
      # one that never closes.
      assert classes("defguard is_ok(x) when x") =~ "‹nf›is_ok‹p›(‹n›x‹p›)"
      assert classes("def f(a,") == "‹kd›def ‹nf›f‹p›(‹n›a‹o›,"
    end

    test "a keyword after a dot is a name" do
      assert classes("Mix.raise(r.end)") == "‹nc›Mix‹o›.‹n›raise‹p›(‹n›r‹o›.‹n›end‹p›)"
      assert classes("raise x") == "‹k›raise ‹n›x"
    end

    test "an escape takes its hex digits" do
      assert classes(~S("\x1f\x4 a")) == ~S(‹s›"‹se›\x1f‹se›\x4‹s› a")
    end

    test "a doc attribute and what it is given are the doc" do
      doc = classes(~s(@moduledoc """\nA room, \\"full\\", \#{@max, 1} seats.\n"""))

      # An escape and a hole inside keep their own colour, and the hole
      # is read like any other code.
      assert doc ==
               ~s(‹sd›@moduledoc ‹sd›"""\nA room, ‹se›\\"‹sd›full‹se›\\"‹sd›, ) <>
                 ~s(‹si›\#{‹na›@max‹o›, ‹mi›1‹si›}‹sd› seats.\n""")

      assert classes("@doc false") == "‹sd›@doc ‹sd›false"
      assert classes(~S(@typedoc "A room.")) == ~S(‹sd›@typedoc ‹sd›"A room.")
      # Any other attribute, and a doc given anything else, stay attributes.
      assert classes("@max 8") == "‹na›@max ‹mi›8"
      assert classes(~S(@doc since: "1.2")) == ~S(‹na›@doc ‹ss›since‹sa›: ‹s›"1.2")
    end
  end

  test "a template's Elixir is left as its lexer sorted it" do
    assert {:ok, :html, html} = Highlight.fenced("heex", "<p class={[a, b]}>{@a}</p>")
    assert html =~ ~s(<span class="p">,</span>)
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
