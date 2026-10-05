defmodule Console.Nodes do
  @moduledoc """
  The Node majors `NODE_VERSION` can name, read off Node's own release
  schedule and NodeSource, where both images take Node from.

  Read here and not through `wb.sh`, for the reason `Console.Installers`
  gives: a fact from the internet is not an action and not a fact about
  the workspace, and `NODE_VERSION` is one key of `config.conf`, which is
  already `config set`'s job.

  Two questions, two sources. Where a major stands today — current, LTS,
  maintenance, end of life, and until when — is the schedule the Node
  project publishes (`nodejs/Release`, `schedule.json`: one entry per
  major with its dates). Whether it can be installed is NodeSource: the
  build takes `nodejs` from `deb.nodesource.com/node_MAJOR.x`, so a
  major that has no repository there stops the build at apt, whatever
  the schedule says. The second is asked once per major, all at once,
  the way the installers' requirements are.

  What this does **not** do is judge: every released major is listed
  with its state and the reader picks. A major NodeSource has not got is
  said, not hidden.
  """

  @schedule ~c"https://raw.githubusercontent.com/nodejs/Release/main/schedule.json"
  @nodesource "https://deb.nodesource.com/node_"
  @timeout 15_000

  @doc """
  `{:ok, majors}`, newest first, or `{:error, why}`. Each major:
  `"major"` (`"24"`), `"state"` (`"current"`, `"lts"`, `"maintenance"`
  or `"end of life"`), `"lts"` (whether the line is or becomes an LTS
  one), `"codename"`, `"until"` (its end of life) and `"nodesource"`
  (whether NodeSource has a repository for it).
  """
  def list(today \\ Date.utc_today()) do
    with {:ok, body} <- get(@schedule),
         {:ok, %{} = schedule} <- Jason.decode(body) do
      {:ok, schedule |> majors(today) |> on_nodesource()}
    else
      {:error, why} -> {:error, why}
      _ -> {:error, "GitHub answered something that is not Node's release schedule"}
    end
  end

  @doc """
  The majors the schedule has released by `today`, newest first, each
  with where it stands that day. A line is `"lts"` from its LTS date,
  `"maintenance"` from its maintenance date, `"end of life"` from its
  end, and `"current"` before any of those; one that has no LTS date
  never becomes one. Nothing is asked of the network: the schedule is
  a map as `schedule.json` decodes.
  """
  def majors(schedule, today) do
    for {"v" <> major, dates} <- schedule,
        {n, ""} <- [Integer.parse(major)],
        reached?(dates["start"], today) do
      %{
        "major" => major,
        "n" => n,
        "state" => state(dates, today),
        "lts" => Map.has_key?(dates, "lts"),
        "codename" => blank_to_nil(dates["codename"]),
        "until" => dates["end"]
      }
    end
    |> Enum.sort_by(& &1["n"], :desc)
    |> Enum.map(&Map.delete(&1, "n"))
  end

  defp state(dates, today) do
    cond do
      reached?(dates["end"], today) -> "end of life"
      reached?(dates["maintenance"], today) -> "maintenance"
      reached?(dates["lts"], today) -> "lts"
      true -> "current"
    end
  end

  # Whether a date of the schedule is today or past; a missing or
  # malformed one is not.
  defp reached?(iso, today) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> Date.compare(date, today) != :gt
      _ -> false
    end
  end

  defp reached?(_, _), do: false

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  # One request per major, all in flight together. A major NodeSource
  # does not answer for is kept and marked, not dropped: the schedule is
  # what Node publishes, and the mark is what the reader needs.
  defp on_nodesource(majors) do
    majors
    |> Task.async_stream(&Map.put(&1, "nodesource", repository?(&1["major"])),
      max_concurrency: 10,
      timeout: @timeout,
      on_timeout: :kill_task
    )
    |> Enum.zip(majors)
    |> Enum.map(fn
      {{:ok, major}, _} -> major
      {_, major} -> Map.put(major, "nodesource", false)
    end)
  end

  defp repository?(major) do
    url = String.to_charlist(@nodesource <> major <> ".x/dists/nodistro/Release")
    headers = [{~c"user-agent", ~c"dockerized-elixir-workbench"}]

    case :httpc.request(:head, {url, headers}, [timeout: @timeout], []) do
      {:ok, {{_, 200, _}, _, _}} -> true
      _ -> false
    end
  end

  # :httpc, as `Console.Installers` uses it: OTP's own, for one file.
  defp get(url) do
    headers = [{~c"user-agent", ~c"dockerized-elixir-workbench"}]

    case :httpc.request(:get, {url, headers}, [timeout: @timeout], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, code, _}, _, _}} -> {:error, "GitHub answered #{code}"}
      {:error, reason} -> {:error, "GitHub could not be reached: #{inspect(reason)}"}
    end
  end
end
