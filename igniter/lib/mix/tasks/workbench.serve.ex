defmodule Mix.Tasks.Workbench.Serve do
  use Mix.Task

  @shortdoc "Answers the console's questions about this project, for as long as it is asked"

  @moduledoc """
  #{@shortdoc}

      mix workbench.serve

  The resident: one BEAM with the project loaded, reading one question
  per line on stdin and answering one JSON line on stdout, until stdin
  ends. What `workbench.status`, `workbench.catalog` and
  `workbench.expand` answer, without booting Mix for each — the console
  keeps one of these per workspace and asks it in milliseconds.

      {"ask": "status"}
      {"ask": "catalog", "covers": "/app/workbench/assets/covers"}
      {"ask": "expand", "name": "chiefs_setup", "argv": ["--interface", "graphql"]}

  Every answer is one line starting with `answer> ` — the rest of the
  output is Mix's, compiling what an insert changed since the last
  question. `{"answer": …}` or `{"error": "…"}`.
  """

  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(_argv) do
    Application.ensure_all_started(:rewrite)
    IO.puts("serve> ready")
    loop()
  end

  defp loop do
    case IO.gets("") do
      :eof ->
        :ok

      {:error, _} ->
        :ok

      line ->
        line |> String.trim() |> answer()
        loop()
    end
  end

  defp answer(""), do: :ok

  defp answer(line) do
    result =
      try do
        # Whatever an insert wrote since the last question is compiled
        # again — Mix remembers which tasks ran, so it is told to forget.
        Mix.Task.clear()
        {:ok, ask(Jason.decode!(line))}
      rescue
        e -> {:error, Exception.message(e)}
      catch
        kind, value -> {:error, "#{kind}: #{inspect(value)}"}
      end

    body =
      case result do
        {:ok, answer} -> %{answer: answer}
        {:error, why} -> %{error: why}
      end

    IO.puts("answer> " <> Jason.encode!(body))
  end

  defp ask(%{"ask" => "status"}), do: Mix.Tasks.Workbench.Status.read()
  defp ask(%{"ask" => "catalog"} = req), do: Mix.Tasks.Workbench.Catalog.read(req["covers"])

  defp ask(%{"ask" => "expand", "name" => name} = req) do
    feature = Features.named(name) || raise("Unknown cartridge: #{name}")

    if feature.pending?(),
      do: raise("The #{name} cartridge is pending: its installer is not done yet.")

    # The console never forces an archived box: the flag that does is
    # the shell's, for a hand rebuilding an old project on purpose.
    if feature.archived?(),
      do: raise("The #{name} cartridge is archived (#{feature.archived()}).")

    for {member, argv} <- Mix.Tasks.Workbench.Expand.plan(feature, req["argv"] || []),
        do: %{name: member, argv: argv}
  end

  defp ask(req), do: raise("not a question: #{inspect(req)}")
end
