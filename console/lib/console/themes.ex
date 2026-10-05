defmodule Console.Themes do
  @moduledoc """
  The themes on the shelf, `console/themes/`, read when the console
  page mounts. Two shelves, one a surface, told apart by the file's
  suffix: `<key>.terminal.json` is a terminal theme — the terminals',
  the logs' and the jobs' colours — and `<key>.code.json` a code theme —
  the sheet, every language's palette and the diff's. A theme is
  colours: the face is the reader's, no theme's. Each carries a
  `dew.theme` that says its name, its author, where it lives, under
  which licence, and — `about`, when it wants to — what it is in a
  sentence, which Credits prints whole; and a block a ground, `dark` and `light`, each in the
  keys VS Code uses; a theme that has no light ground carries no `light`
  block, and on that ground the house's is shown. The drawer's Terminal
  and Code parts each offer their shelf and Credits lists both; the
  reader's own, downloaded from the drawer, is a file to drop here. A
  file that is not JSON, has no name, or wears neither suffix is left
  out with a warning: the shelf never fails for one bad theme.
  """
  require Logger

  @type kind :: :terminal | :code
  @type t :: %{
          key: String.t(),
          kind: kind(),
          name: String.t(),
          author: String.t() | nil,
          url: String.t() | nil,
          licence: String.t() | nil,
          about: String.t() | nil,
          json: map()
        }

  @kinds %{"terminal" => :terminal, "code" => :code}

  @doc """
  Every theme on both shelves, the terminal's first; on a shelf the
  house's first (the key `default`: what a theme does not say, it says)
  and the rest by name. The shelf is the configured directory
  (`:themes_dir`) unless one is given.
  """
  @spec all(Path.t() | nil) :: [t()]
  def all(dir \\ nil) do
    dir = Path.expand(dir || Application.get_env(:console, :themes_dir, "themes"))

    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.flat_map(&read/1)
    |> Enum.sort_by(&{&1.kind != :terminal, &1.key != "default", &1.name})
  end

  @doc "One shelf: the terminal themes, or the code themes, the house's first."
  @spec shelf(kind(), Path.t() | nil) :: [t()]
  def shelf(kind, dir \\ nil) when kind in [:terminal, :code],
    do: Enum.filter(all(dir), &(&1.kind == kind))

  defp read(path) do
    with {:ok, kind, key} <- kind_of(path),
         {:ok, text} <- File.read(path),
         {:ok, %{"dew.theme" => %{"name" => name} = meta} = json}
         when is_binary(name) and name != "" <-
           Jason.decode(text) do
      [
        %{
          key: key,
          kind: kind,
          name: name,
          author: string(meta["author"]),
          url: string(meta["url"]),
          licence: string(meta["licence"] || meta["license"]),
          about: string(meta["about"]),
          json: json
        }
      ]
    else
      other ->
        Logger.warning("theme #{path} left out: #{inspect(other)}")
        []
    end
  end

  # `<key>.terminal.json` or `<key>.code.json`: the suffix is the shelf.
  defp kind_of(path) do
    case path |> Path.basename(".json") |> String.split(".") do
      [key, suffix] when is_map_key(@kinds, suffix) and key != "" ->
        {:ok, Map.fetch!(@kinds, suffix), key}

      _ ->
        {:error, :no_shelf}
    end
  end

  defp string(v) when is_binary(v) and v != "", do: v
  defp string(_), do: nil
end
