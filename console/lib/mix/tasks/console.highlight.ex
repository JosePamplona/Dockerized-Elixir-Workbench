defmodule Mix.Tasks.Console.Highlight do
  @shortdoc "Colours files for the console, and for the mock's build"

  @moduledoc """
  Applies `Console.Highlight` to a batch of files and answers as JSON, so
  the mock's generator can ask for the same colouring the console does
  rather than growing a second one of its own.

      mix console.highlight            # a batch on stdin, the answer on stdout
      mix console.highlight --registry # what the registry covers, and with what

  It takes *contents*, not paths: what the console shows comes out of a
  git commit, not off the disk, so there is nothing to open. The path
  rides along because it is what decides the treatment.

      in   [{"path": "lib/a.ex", "source": "defmodule A do\\nend\\n"}, ...]
      out  [{"path": "lib/a.ex", "treatment": "lexer", "html": "...", "error": null}, ...]
  """
  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:makeup)

    if "--registry" in argv do
      r = Console.Highlight.registry()

      IO.puts(
        Jason.encode!(
          %{
            names: Map.new(r.names, fn {k, v} -> {k, label(v)} end),
            extensions: Map.new(r.extensions, fn {k, v} -> {k, label(v)} end)
          },
          pretty: true
        )
      )
    else
      IO.stream(:stdio, :line)
      |> Enum.join()
      |> Jason.decode!()
      |> Enum.map(fn %{"path" => path, "source" => source} ->
        Console.Highlight.render(path, source) |> Map.put(:path, path)
      end)
      |> Jason.encode!()
      |> IO.puts()
    end
  end

  defp label({:lexer, module}), do: inspect(module)
  defp label(atom), do: to_string(atom)
end
