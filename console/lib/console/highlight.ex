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
  of), a Godot scene (through INI, which it is shaped like) and the
  shell read through it, as `{MakeupSyntect.Lexer, language: "..."}`,
  a lexer with the options it lexes with. The language is syntect's: a
  file extension it knows, `gd` and not `gdscript`, `sh` and not `bash`.

  Elixir's tokens take one more pass before they are drawn,
  `Console.Highlight.ElixirTokens`: Makeup's lexer sorts them coarser than the
  grammar VS Code reads Elixir with, and the palette is a VS Code theme.
  A comma is punctuation like a bracket to the one and a separator to
  the other; `@doc "..."` an attribute and a string, or documentation.
  That module says which, token by token. A template's Elixir is left
  as lexed: it reads with HTML's palette.

  A second registry, `@by_fence`, is the same treatments by the name a
  Markdown fence opens with (` ```elixir `): the papers a box carries
  and the project's own are rendered by `Console.Papers`, and a fenced
  block whose language is here is coloured as the Files sheet would
  colour the file, with its palette. A fence named nothing, or named
  something not here, stays as the renderer wrote it: plain.
  """

  alias Console.Highlight.ElixirTokens
  alias Makeup.Formatters.HTML.HTMLFormatter
  alias Makeup.Lexers.ElixirLexer
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

  # A fence's name is what its author typed after the backticks: the
  # names GitHub's own highlighter answers to, so a paper written for
  # the repository reads the same here. `shell` and `zsh` read as `sh`
  # — the grammar is one — and `jsonc` is not `json`: the JSON lexer
  # does not know a comment. Counted on the papers on 2026-09-29: `sh`
  # 46, `elixir` 32, `bash` 2, `markdown` 3, `css` 1.
  @by_fence %{
    "elixir" => {:lexer, Makeup.Lexers.ElixirLexer, :elixir},
    "heex" => {:lexer, Makeup.Lexers.HEExLexer, :html},
    "eex" => {:lexer, Makeup.Lexers.EExLexer, :html},
    "html" => {:lexer, Makeup.Lexers.HTMLLexer, :html},
    "css" => {:lexer, MakeupCSS.Lexer, :css},
    "scss" => {:lexer, {MakeupSyntect.Lexer, language: "scss"}, :css},
    "js" => {:lexer, Makeup.Lexers.JsLexer, :ts},
    "javascript" => {:lexer, Makeup.Lexers.JsLexer, :ts},
    "ts" => {:lexer, MakeupTS.Lexer, :ts},
    "typescript" => {:lexer, MakeupTS.Lexer, :ts},
    "json" => {:lexer, Makeup.Lexers.JsonLexer, :json},
    "markdown" => {:lexer, {MakeupSyntect.Lexer, language: "markdown"}, :markdown},
    "md" => {:lexer, {MakeupSyntect.Lexer, language: "markdown"}, :markdown},
    "gd" => {:lexer, {MakeupSyntect.Lexer, language: "gd"}, :godot},
    "gdscript" => {:lexer, {MakeupSyntect.Lexer, language: "gd"}, :godot},
    "gdshader" => {:lexer, {MakeupSyntect.Lexer, language: "glsl"}, :godot},
    "sh" => {:lexer, {MakeupSyntect.Lexer, language: "sh"}, :shell},
    "bash" => {:lexer, {MakeupSyntect.Lexer, language: "sh"}, :shell},
    "shell" => {:lexer, {MakeupSyntect.Lexer, language: "sh"}, :shell},
    "zsh" => {:lexer, {MakeupSyntect.Lexer, language: "sh"}, :shell}
  }

  @doc "The registry, for a page that wants to show what is covered."
  @spec registry() :: %{names: map(), extensions: map(), fences: map()}
  def registry, do: %{names: @by_name, extensions: @by_extension, fences: @by_fence}

  @doc """
  A fenced block, coloured as a file of its language would be: the
  palette's name and the inner HTML, or `:plain` when the fence names
  nothing this registry has — or when the lexer fails on it, which is
  the block's problem and not the page's. The info string is what
  follows the backticks; only its first word names the language
  (` ```sh title="x" ` is a fence GitHub reads), and case does not count.
  """
  @spec fenced(binary(), binary()) :: {:ok, atom(), binary()} | :plain
  def fenced(info, source) do
    with [word | _] <- info |> String.trim() |> String.downcase() |> String.split(~r/\s+/),
         {:lexer, lexer, lang} <- Map.get(@by_fence, word, :plain),
         %{treatment: :lexer, html: html} <- highlight(lexer, source) do
      {:ok, lang, html}
    else
      _ -> :plain
    end
  end

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
  defp lex(ElixirLexer, source),
    do: source |> ElixirLexer.lex() |> ElixirTokens.as_its_editor_reads()

  defp lex(lexer, source) when is_atom(lexer), do: lexer.lex(source)
  defp lex({lexer, opts}, source), do: lexer.lex(source, opts)

  defp inner_html(:plain, source), do: escape(source)

  defp inner_html(lexer, source),
    do: lexer |> lex(source) |> HTMLFormatter.format_inner_as_binary([])

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
  # a doc, an attribute, `use`, strings, atoms, a number, a function,
  # operators, a capture's `&1`, a regex, brackets and a comment.
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
           if valid? do
             {:ok, %{room | players: [p | ps]}}
           else
             {:error, :refused}
           end
         end

         def leave(%{players: ps} = room, %Player{id: id}) do
           {gone, kept} = Enum.split_with(ps, &(&1.id == id))

           case gone do
             [] -> {:error, :not_here}
             [_] -> {:ok, %{room | players: kept}}
           end
         end

         @doc "The room as the band reads it: a name and a count."
         def summary(%{name: name, players: ps}) do
           "\#{name}: \#{length(ps)}/\#{@max}"
         end

         def handle_call({:join, p}, _from, room) do
           case join(room, p) do
             {:ok, room} ->
               {:reply, :ok, room}

             {:error, why} = err ->
               {:reply, err, Map.update(room, :refused, [why], &[why | &1])}
           end
         end

         def handle_info(:tick, room) do
           Process.send_after(self(), :tick, 1_000)
           {:noreply, %{room | ticks: room.ticks + 1}}
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
       <section class="board" phx-update="ignore" id="room-1-board">
         <h2>{@room.name} <small>{length(@players)}/8</small></h2>
         <form phx-submit="join" phx-change="validate">
           <input
             type="text"
             name="name"
             value={@form[:name].value}
             placeholder="your name"
           />
           <input type="number" name="age" min="18" max="120" />
           <button type="submit" disabled={@late}>Join</button>
         </form>
         <p :if={@late} class="late">
           The room is full: come back at <time>{@next}</time>.
         </p>
         <table>
           <tr :for={{p, i} <- Enum.with_index(@players, 1)}>
             <td>{i}</td>
             <td>{p.name}</td>
             <td>{p.age}</td>
           </tr>
         </table>
         <footer>
           <.link navigate={~p"/rooms"} class="back">All rooms</.link>
           <span class="count">{length(@players)} of {@max}</span>
         </footer>
       </section>

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

       .players {
         display: grid;
         gap: 6px 12px;
         grid-template-columns: 2ch 1fr auto;
       }
       .players .late {
         color: var(--muted);
         text-decoration: line-through;
        }

       .board h2 small {
         font-size: .7em;
         opacity: .6;
         margin-left: .5ch;
       }
       .board form {
         display: flex;
         gap: 8px;
         align-items: center;
       }
       .board input[type="number"] {
         width: 5ch;
         text-align: right;
       }
       .board button:disabled {
         cursor: not-allowed;
         opacity: .5;
       }
       .board table {
         border-collapse: collapse;
         width: 100%;
       }
       .board td {
         padding: 2px 6px;
         border-bottom: 1px solid #eee;
       }
       .board tr:nth-child(odd) td { background: rgba(0, 0, 0, .03); }

       /* the late one blinks until the next seat */
       @keyframes pulse { 50% { opacity: .2; } }
       .late time { animation: pulse 1.2s infinite; }
       .back::before { content: "←"; margin-right: .4ch; }
       .count { font-variant-numeric: tabular-nums; float: right; }

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
         "db": { "pool": 10, "url": "ecto://arcade@db/arcade" },
         "rooms": [
           { "id": 1, "name": "lobby", "max": 8, "open": true },
           { "id": 2, "name": "arena", "max": 4, "open": false },
           { "id": 3, "name": "balcony", "max": 2, "open": true }
         ],
         "limits": {
           "age": 18,
           "idle_seconds": 300,
           "rate": 2.5
         },
         "features": {
           "chat": true,
           "spectators": false,
           "replays": null
         },
         "mail": {
           "from": "arcade@example.test",
           "retries": 3
         },
         "log": {
           "level": "info",
           "json": true,
           "file": "/var/log/arcade.log"
         },
         "build": "2026-09-30T18:00:00Z"
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

       const socket = new Socket(
         "/socket",
         { params: { token: `t-${id}` } }
       );
       socket.connect();

       const channel = socket.channel(`room:${id}`, { age: 21 });
       channel.on("joined", ({ name, count }: { name: string; count: number }) => {
         console.log(`${name} joined; ${count} in the room`);
       });
       channel.join()
         .receive("ok", () => render(document.getElementById("board")!))
         .receive("error", (why: unknown) => console.error("refused", why));

       // The board: one row a player, the late one greyed.
       function render(el: HTMLElement): void {
         const rows = players.map(
           (p, i) => `<tr><td>${i + 1}</td><td>${p.name}</td></tr>`
         );
         el.innerHTML = rows.join("");
       }

       type Player = { name: string; age: number };
       const players: Player[] = [];

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

       ## Rooms

       | Room    | Max | Open |
       | ------- | --- | ---- |
       | lobby   | 8   | yes  |
       | arena   | 4   | no   |

       1. Pick a room.
       2. Give your name and your age.
       3. Wait for the band to say *joined*.

       ### Limits

       The room turns a player away when it is **full**, when the player is
       under 18, or when the name has anything but `a-z` and `_`.

       ---

       See [the design](DESIGN.md) for why eight, and the `CHANGELOG.md` for
       the day it became twelve.

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

       func take_hit(amount: int) -> void:
       	health -= amount
       	if health <= 0:
       		is_dead = true
       		$Sprite2D.modulate = Color(0.4, 0.4, 0.4, 1.0)
       		died.emit()

       func _on_area_body_entered(body: Node2D) -> void:
       	if body.is_in_group("spikes"):
       		take_hit(25)
       	elif body.name == "Coin":
       		coins += 1
       		body.queue_free()

       var health: int = 100
       var coins: int = 0
       var is_dead := false
       const JUMP_FORCE := -400.0
       """},
    shell:
      {{MakeupSyntect.Lexer, language: "sh"},
       """
       #!/usr/bin/env bash
       # One room a workspace; the port comes from .env.
       set -euo pipefail

       export PORT="${PORT:-4000}"
       if [ ! -f .env ]; then
         echo "no .env in $PWD" >&2
         exit 1
       fi

       players=$(mix run -e 'IO.puts 8' | tr -d '\\n')
       for f in lib/*.ex; do wc -l "$f"; done
       mix phx.server && echo "room on :$PORT, $players at most"

       rooms=("lobby" "arena" "balcony")
       for room in "${rooms[@]}"; do
         if docker compose ps --status running | grep -q "$room"; then
           printf '%-8s up\\n' "$room"
         else
           printf '%-8s down\\n' "$room" >&2
         fi
       done

       case "${1:-}" in
         start) docker compose up -d --wait ;;
         stop)  docker compose down ;;
         *)     echo "usage: $0 start|stop" >&2; exit 2 ;;
       esac

       trap 'echo "bye"; exit 0' INT TERM

       while read -r line; do
         [[ "$line" =~ ^#.*$ ]] && continue
         echo "$line" | tee -a room.log
       done < players.txt

       """},
    # A file with no language — no lexer answers to .toml — read in the
    # sheet's own foreground, for the Interface tab's *Other*.
    other:
      {:plain,
       """
       # The room's own settings; the port comes from .env.
       name = "lobby"
       max = 8
       open = true

       [limits]
       age = 18
       idle_seconds = 300
       rate = 2.5

       [mail]
       from = "arcade@example.test"
       retries = 3
       """}
  }

  @doc "The samples the Interface tab's sheet shows: a language each, and Other, a file with none."
  @spec samples() :: [atom()]
  def samples, do: languages() ++ [:other]

  @doc "The languages the Interface tab shows a palette for, in its order."
  @spec languages() :: [atom()]
  def languages, do: [:elixir, :html, :css, :ts, :json, :markdown, :godot, :shell]

  @doc "A language's sample, coloured by its lexer: inner HTML for a `.src`."
  @spec sample(atom()) :: binary()
  def sample(lang \\ :elixir) do
    {lexer, source} = Map.fetch!(@samples, lang)
    inner_html(lexer, source)
  end

  # One line of each sample changed — the number the sample is about,
  # a little bigger — so the Interface tab's sheet shows a removal and
  # an addition in every language, as the Files sheet colours them.
  @sample_edits %{
    elixir: {6, "  @max 12"},
    html: {3, ~s(  <li :for={p <- @players} :if={p.age >= 18} data-max="12">)},
    css: {3, "  margin: 0 12px;"},
    json: {3, ~s(  "port": 4001,)},
    ts: {4, "  max: number = 12;"},
    markdown: {6, "- twelve at most"},
    godot: {4, "@export var speed: float = 240.0"},
    shell: {9, "players=$(mix run -e 'IO.puts 12' | tr -d '\\n')"},
    other: {3, "max = 12"}
  }

  @doc """
  The sample as a patch, for the sheet the Interface tab draws it on:
  the rows the Files sheet draws (`Console.Diffs`: `{class, old number,
  new number, sign, html}`, nil for a number a row has not) — one hunk, every line context but the one that changed,
  which is a removal and then an addition. Both faces are lexed whole,
  as the Files sheet lexes them, so a token that spans lines keeps its
  colour on either side of the change.
  """
  @spec sample_diff(atom()) :: [
          {atom(), pos_integer() | String.t(), pos_integer() | String.t(), String.t(), String.t()}
        ]
  def sample_diff(lang \\ :elixir) do
    {lexer, source} = Map.fetch!(@samples, lang)
    {k, new_line} = Map.fetch!(@sample_edits, lang)
    old = lines_of(lexer, source)

    new =
      lines_of(
        lexer,
        source |> String.split("\n") |> List.replace_at(k - 1, new_line) |> Enum.join("\n")
      )

    n = length(old)

    [{:hunk, nil, nil, "", escape("@@ -1,#{n} +1,#{n} @@")}] ++
      Enum.flat_map(Enum.with_index(old, 1), fn
        {line, ^k} -> [{:del, k, nil, "−", line}, {:add, nil, k, "+", Enum.at(new, k - 1)}]
        {line, i} -> [{:ctx, i, i, " ", line}]
      end)
  end

  defp lines_of(:plain, source), do: plain_lines(String.trim_trailing(source, "\n"))

  defp lines_of(lexer, source),
    do: lexer |> lex(String.trim_trailing(source, "\n")) |> token_lines()

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

        case value |> text() |> String.split("\n") do
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

  # A lexer may hand a lone codepoint as the value; chardata wants a list.
  defp text(value), do: value |> List.wrap() |> IO.chardata_to_string()

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
