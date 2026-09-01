defmodule Console.Highlight do
  @moduledoc """
  What the console does with a file it shows.

  The registry below is data: a treatment per exact filename first, per
  extension after. There are four of them, because a lexer is not the
  answer to every file — an SVG is a drawing, and `mix.lock` is a wall of
  thousand-character lines nobody reads.

      {:lexer, module}  colour it
      :image            show the file, not its text
      :plain            show the text, uncoloured
      :omit             do not show it; the counts already said enough

  Adding a language is one line here and its `makeup_*` dependency. Every
  Makeup lexer emits the same token vocabulary — the Pygments classes the
  palette is written against — so a new language costs no stylesheet.

  What is not in the registry is never guessed at. Handing an unknown
  file to the nearest lexer does not leave it grey, it makes it wrong:
  `_style.html.eex` through the Elixir lexer colours `in` and `with` as
  keywords inside a CSS comment, and `:root` as an atom. Unknown means
  `:plain`. When a file we do care about has no `makeup_*` of its own,
  `makeup_syntect` — the Sublime grammars behind a precompiled Rust NIF,
  from the same makeup organisation — is the escape hatch to reach for
  then, and nothing above has to change to let it in.
  """

  # Whole names win over extensions: `.lock` says nothing anywhere else,
  # and mix.lock is an Elixir map literal, so it is read by the lexer its
  # contents ask for rather than by its extension. Its lines run past a
  # thousand characters, which is a reason to let it scroll and not a
  # reason to leave it out: the lock is the only place a cartridge shows
  # what it *drags in*. `credo` puts one line in mix.exs; the lock is
  # where bunt, file_system and the rest of its tree become visible.
  @by_name %{
    "mix.lock" => {:lexer, Makeup.Lexers.ElixirLexer}
  }

  @by_extension %{
    ".ex" => {:lexer, Makeup.Lexers.ElixirLexer},
    ".exs" => {:lexer, Makeup.Lexers.ElixirLexer},
    ".heex" => {:lexer, Makeup.Lexers.HEExLexer},
    # `.html.eex` and `.html.heex` land here by their last extension,
    # which is the right one: the outer language is the template's.
    ".eex" => {:lexer, Makeup.Lexers.EExLexer},
    ".html" => {:lexer, Makeup.Lexers.HTMLLexer},
    ".js" => {:lexer, Makeup.Lexers.JsLexer},
    ".json" => {:lexer, Makeup.Lexers.JsonLexer},
    # Drawings, not documents: a cartridge's diagrams are a thousand
    # lines of XML that say nothing to a reader and everything to a
    # browser.
    ".svg" => :image,
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
  @spec treatment(binary()) :: {:lexer, module()} | :image | :plain | :omit
  def treatment(path) do
    name = Path.basename(path)

    case Map.fetch(@by_name, name) do
      {:ok, t} -> t
      :error -> Map.get(@by_extension, String.downcase(Path.extname(name)), :plain)
    end
  end

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

  defp highlight(lexer, source) do
    %{treatment: :lexer, html: Makeup.highlight_inner_html(source, lexer: lexer), error: nil}
  rescue
    e -> %{treatment: :plain, html: nil, error: Exception.message(e)}
  catch
    kind, value -> %{treatment: :plain, html: nil, error: "#{kind}: #{inspect(value)}"}
  end
end
