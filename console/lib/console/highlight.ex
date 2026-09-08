defmodule Console.Highlight do
  @moduledoc """
  What the console does with a file it shows.

  The registry below is data: a treatment per exact filename first, per
  extension after. There are four of them, because a lexer is not the
  answer to every file — an SVG is a drawing, and `mix.lock` is a wall of
  thousand-character lines nobody reads.

      {:lexer, module, language}  colour it, and say which palette
      :image                      show the file, not its text
      :plain                      show the text, uncoloured
      :omit                       do not show it; the counts already said enough

  Adding a language is one line here and its `makeup_*` dependency. Every
  Makeup lexer emits the same token vocabulary — the Pygments classes the
  palette is written against — so a new language costs no stylesheet.
  The language is the palette's name: the reader keeps one set of colours
  per language in the Interface tab (`elixir`, `json`, `ts`, `markdown`),
  and the sheet stamps it on the `.src` as `data-lang`. HEEx and EEx read
  with HTML's — a template is a page first — JavaScript with TypeScript's,
  SCSS with CSS's, and Godot's four kinds of file with one palette: a
  script, a shader, a scene, the project.

  What is not in the registry is never guessed at. Handing an unknown
  file to the nearest lexer does not leave it grey, it makes it wrong:
  `_style.html.eex` through the Elixir lexer colours `in` and `with` as
  keywords inside a CSS comment, and `:root` as an atom. Unknown means
  `:plain`. When a file we do care about has no `makeup_*` of its own,
  `makeup_syntect` — the Sublime grammars behind a precompiled Rust NIF,
  from the same makeup organisation — is the escape hatch: Markdown,
  SCSS, GDScript, a Godot shader (through GLSL, which it is a dialect
  of) and a Godot scene (through INI, which it is shaped like) read
  through it, as `{MakeupSyntect.Lexer, language: "..."}`, a lexer with
  the options it lexes with. The language is syntect's: a file
  extension it knows, `gd` and not `gdscript`.
  """

  alias Makeup.Token.Utils

  # Whole names win over extensions: `.lock` says nothing anywhere else,
  # and mix.lock is an Elixir map literal, so it is read by the lexer its
  # contents ask for rather than by its extension. Its lines run past a
  # thousand characters, which is a reason to let it scroll and not a
  # reason to leave it out: the lock is the only place a cartridge shows
  # what it *drags in*. `credo` puts one line in mix.exs; the lock is
  # where bunt, file_system and the rest of its tree become visible.
  @by_name %{
    "mix.lock" => {:lexer, Makeup.Lexers.ElixirLexer, :elixir},
    "project.godot" => {:lexer, {MakeupSyntect.Lexer, language: "ini"}, :godot}
  }

  @by_extension %{
    ".ex" => {:lexer, Makeup.Lexers.ElixirLexer, :elixir},
    ".exs" => {:lexer, Makeup.Lexers.ElixirLexer, :elixir},
    ".heex" => {:lexer, Makeup.Lexers.HEExLexer, :html},
    # `.html.eex` and `.html.heex` land here by their last extension,
    # which is the right one: the outer language is the template's.
    ".eex" => {:lexer, Makeup.Lexers.EExLexer, :html},
    ".html" => {:lexer, Makeup.Lexers.HTMLLexer, :html},
    ".css" => {:lexer, MakeupCSS.Lexer, :css},
    ".scss" => {:lexer, {MakeupSyntect.Lexer, language: "scss"}, :css},
    ".gd" => {:lexer, {MakeupSyntect.Lexer, language: "gd"}, :godot},
    ".gdshader" => {:lexer, {MakeupSyntect.Lexer, language: "glsl"}, :godot},
    ".tscn" => {:lexer, {MakeupSyntect.Lexer, language: "ini"}, :godot},
    ".tres" => {:lexer, {MakeupSyntect.Lexer, language: "ini"}, :godot},
    ".js" => {:lexer, Makeup.Lexers.JsLexer, :ts},
    ".ts" => {:lexer, MakeupTS.Lexer, :ts},
    ".json" => {:lexer, Makeup.Lexers.JsonLexer, :json},
    # The papers a cartridge writes — README, AGENTS.md, a guide — read
    # here as what the cartridge wrote, coloured: heads, emphasis, code.
    ".md" => {:lexer, {MakeupSyntect.Lexer, language: "markdown"}, :markdown},
    # An SVG is text, and on this sheet the question is what the cartridge
    # wrote — so it is read like any other text file it wrote, with its
    # patch and its line numbers. Drawing it instead answered a question
    # nobody asked here, and asked the page to host a foreign stylesheet,
    # forty ids and, in an exported one, a <script> block. Plain and not a
    # lexer: XML is not HTML, and the registry never guesses.
    ".svg" => :plain,
    ".png" => :image,
    ".jpg" => :image,
    ".jpeg" => :image,
    ".webp" => :image
  }

  @doc "The registry, for a page that wants to show what is covered."
  @spec registry() :: %{names: map(), extensions: map()}
  def registry, do: %{names: @by_name, extensions: @by_extension}

  @doc """
  What to do with this path. Never raises, and never guesses: a file the
  registry does not name is `:plain`.
  """
  @spec treatment(binary()) :: {:lexer, lexer()} | :image | :plain | :omit
  def treatment(path) do
    case entry(path) do
      {:lexer, lexer, _lang} -> {:lexer, lexer}
      other -> other
    end
  end

  @typedoc "A Makeup lexer, alone or with the options it lexes with."
  @type lexer :: module() | {module(), keyword()}

  @doc "The palette a file is coloured with, or nil when it is not coloured."
  @spec lang(binary()) :: atom() | nil
  def lang(path) do
    case entry(path) do
      {:lexer, _lexer, lang} -> lang
      _ -> nil
    end
  end

  defp entry(path) do
    name = Path.basename(path)

    case Map.fetch(@by_name, name) do
      {:ok, t} -> t
      :error -> Map.get(@by_extension, String.downcase(Path.extname(name)), :plain)
    end
  end

  # The two shapes a lexer takes, lexed and rendered the same way.
  defp lex(lexer, source) when is_atom(lexer), do: lexer.lex(source)
  defp lex({lexer, opts}, source), do: lexer.lex(source, opts)

  defp inner_html(lexer, source) when is_atom(lexer),
    do: Makeup.highlight_inner_html(source, lexer: lexer)

  defp inner_html({lexer, opts}, source),
    do: Makeup.highlight_inner_html(source, lexer: lexer, lexer_options: opts)

  @doc """
  The file as the page should receive it: the treatment that was applied,
  and the HTML when there is any to give.

  A lexer that blows up on a file falls back to `:plain` and says so in
  `:error` rather than taking the page down with it — but it says so,
  because a lexer failing quietly is how you end up shipping a page that
  colours nothing and nobody notices.
  """
  @spec render(binary(), binary()) :: %{
          treatment: atom(),
          html: binary() | nil,
          error: binary() | nil
        }
  def render(path, source) do
    case treatment(path) do
      {:lexer, lexer} -> highlight(lexer, source)
      :image -> %{treatment: :image, html: nil, error: nil}
      :omit -> %{treatment: :omit, html: nil, error: nil}
      :plain -> %{treatment: :plain, html: nil, error: nil}
    end
  end

  # A few lines a language, touching every rule of its palette — for the
  # Interface tab to show the colours on. Elixir's: keywords, a module,
  # an attribute, `use`, strings, atoms, a number, a function, operators,
  # a regex, brackets and a comment.
  @samples %{
    elixir:
      {Makeup.Lexers.ElixirLexer,
       """
       defmodule Arcade.Room do
         @moduledoc "A room, and the players in it."
         use GenServer
         alias Arcade.{Repo, Player}

         @max 8
         # A late player is turned away; nil is nobody.
         def join(%{players: ps} = room, %Player{} = p) when length(ps) < @max do
           valid? = Regex.match?(~r/^[a-z_]+$/, p.name) && p.age >= 18
           if valid?, do: {:ok, %{room | players: [p | ps]}}, else: {:error, :refused}
         end
       end
       """},
    html:
      {Makeup.Lexers.HEExLexer,
       """
       <!-- One row a player; the late one is greyed. -->
       <ul class={["players", @late && "late"]} id="room-1">
         <li :for={p <- @players} :if={p.age >= 18} data-max="8">
           <a href={~p"/players/\#{p.id}"}>{p.name}</a> <%= @max %>
         </li>
       </ul>
       """},
    css:
      {MakeupCSS.Lexer,
       """
       .room > a:hover, #r1 {
         color: #d4b27e;
         margin: 0 14px !important;
         font: 12.5px/1.5 var(--mono);
         background: url("seal.png");
       }
       /* the band */
       @media (max-width: 700px) { .room { display: none } }
       """},
    json:
      {Makeup.Lexers.JsonLexer,
       """
       {
         "name": "arcade",
         "port": 4000,
         "ssl": false,
         "replicas": null,
         "tags": ["live", "dev"],
         "db": { "pool": 10, "url": "ecto://arcade@db/arcade" }
       }
       """},
    ts:
      {MakeupTS.Lexer,
       """
       import { Socket } from "phoenix";
       // One socket per tab; the token comes from the page.
       export class Room<T> extends Base {
         max: number = 8;
         join(p: Player): boolean {
           return this.max > 0 && p.age >= 18;
         }
       }
       const socket = new Socket("/socket", { params: { token: `t-${id}` } });
       """},
    markdown:
      {{MakeupSyntect.Lexer, language: "markdown"},
       """
       # Arcade

       A room holds its **players**, and a *late* one is turned away.
       Run `mix phx.server`, then open [the room](http://localhost:4000).

       - eight at most
       - one socket per tab

       > The token comes from the page.

       ```elixir
       Room.join(room, player)
       ```
       """},
    godot:
      {{MakeupSyntect.Lexer, language: "gd"},
       """
       extends CharacterBody2D
       class_name Player

       @export var speed: float = 200.0
       signal died

       # Move on input; a dead player stays put.
       func _physics_process(delta: float) -> void:
       	velocity = Input.get_vector("left", "right", "up", "down") * speed
       	if velocity.length() > 0 and not is_dead:
       		move_and_slide()
       	died.emit()
       """}
  }

  @doc "The languages the Interface tab shows a palette for, in its order."
  @spec languages() :: [atom()]
  def languages, do: [:elixir, :html, :css, :ts, :json, :markdown, :godot]

  @doc "A language's sample, coloured by its lexer: inner HTML for a `.src`."
  @spec sample(atom()) :: binary()
  def sample(lang \\ :elixir) do
    {lexer, source} = Map.fetch!(@samples, lang)
    inner_html(lexer, source)
  end

  @doc """
  The file one line at a time, for a sheet that shows a patch: the
  treatment, and — for a lexer or plain — one HTML string per line,
  every span closed on its own line. Makeup's newlines sit inside the
  tokens (a heredoc is one span twenty lines tall), so the lines are
  cut from the tokens, never from the HTML.
  """
  @spec lines(binary(), binary()) :: {:lexer | :plain, [binary()]} | :image | :omit
  def lines(path, source) do
    case treatment(path) do
      {:lexer, lexer} ->
        try do
          {:lexer, lexer |> lex(source) |> token_lines()}
        rescue
          _ -> {:plain, plain_lines(source)}
        catch
          _, _ -> {:plain, plain_lines(source)}
        end

      :plain ->
        {:plain, plain_lines(source)}

      other ->
        other
    end
  end

  defp plain_lines(source), do: source |> String.split("\n") |> Enum.map(&escape/1)

  defp token_lines(tokens) do
    {lines, current} =
      Enum.reduce(tokens, {[], []}, fn {type, _meta, value}, {lines, current} ->
        class = Utils.css_class_for_token_type(type)

        case value |> IO.chardata_to_string() |> String.split("\n") do
          [only] ->
            {lines, [span(class, only) | current]}

          [first | rest] ->
            {last, middle} = List.pop_at(rest, -1)
            done = [[span(class, first) | current] | Enum.map(middle, &[span(class, &1)])]
            {Enum.reverse(done) ++ lines, [span(class, last)]}
        end
      end)

    [current | lines]
    |> Enum.reverse()
    |> Enum.map(&(&1 |> Enum.reverse() |> IO.iodata_to_binary()))
  end

  defp span(_class, ""), do: ""
  defp span(nil, text), do: escape(text)
  defp span(class, text), do: [~s(<span class="), class, ~s(">), escape(text), "</span>"]

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp highlight(lexer, source) do
    %{treatment: :lexer, html: inner_html(lexer, source), error: nil}
  rescue
    e -> %{treatment: :plain, html: nil, error: Exception.message(e)}
  catch
    kind, value -> %{treatment: :plain, html: nil, error: "#{kind}: #{inspect(value)}"}
  end
end
