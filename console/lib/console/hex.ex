defmodule Console.Hex do
  @moduledoc """
  What hex.pm says of a package: its latest stable release, when that
  release was published, and how much it is downloaded.

  A reading of the **ecosystem**, not of the project — which is why it
  lives here and not in the igniter package. What a box installs and
  what a project pins are read off the manifest and off `mix.exs` and
  `mix.lock`, offline, by `mix workbench.status`; this is the other
  half, and it is the half that can fail. An installer that asked
  hex.pm would gain a way to fail with no network and write nothing
  different for it: the shelf archived a cartridge for reaching the
  network at insert time (guidelines), and this keeps that line.

  It is never read on its own, as the stacks and the installers are
  not (`Console.Bench`): no clock refreshes it, the page that shows it
  does not ask for it, and a call happens because a reader pressed for
  it. What comes back is held for every page until pressed again.

  One request per package, all in flight together, and a package that
  does not answer carries its reason rather than dropping out of the
  list: a hole is a thing to say, not to hide.

  The call itself is a function this takes, `get/1` by default: the
  suite hands it hex's own answer, captured from the package endpoint,
  and holds what is read out of it — the latest stable release, the day
  it was published, the downloads — without a test ever calling
  hex.pm. A test that reached the network would be a test that fails
  when a train goes into a tunnel, and one that tells somebody else's
  service how often this suite runs.
  """

  @package "https://hex.pm/api/packages/"
  @timeout 10_000

  @doc """
  `%{name => reading}` for each package named, where a reading is
  `%{latest:, released_at:, downloads:}` or `%{error:}`. `released_at`
  is an ISO 8601 string as hex writes it; the console says the distance
  from it, and never invents one.
  """
  @spec read([String.t()], (String.t() -> {:ok, binary()} | {:error, String.t()})) ::
          %{String.t() => map()}
  def read(names, fetch \\ &get/1) when is_list(names) do
    names
    |> Enum.uniq()
    |> Task.async_stream(&{&1, package(&1, fetch)},
      max_concurrency: 10,
      timeout: @timeout + 1_000,
      on_timeout: :kill_task
    )
    |> Enum.zip(Enum.uniq(names))
    |> Map.new(fn
      {{:ok, {name, reading}}, _asked} -> {name, reading}
      {_, asked} -> {asked, %{error: "hex.pm did not answer in time"}}
    end)
  end

  defp package(name, fetch) do
    with {:ok, body} <- fetch.(@package <> name),
         {:ok, json} <- Jason.decode(body) do
      reading(json)
    else
      # The fetch's own reason, which is a sentence; anything else —
      # Jason's decode error among them — is hex answering something
      # this does not know how to read, and says so in words.
      {:error, why} when is_binary(why) -> %{error: why}
      _ -> %{error: "hex.pm answered something that is not a package"}
    end
  end

  # The latest *stable* release and the day it was published: hex lists
  # its releases newest first, and the entry for that version carries
  # the date. A package with no stable release says so.
  defp reading(%{"latest_stable_version" => version} = json) when is_binary(version) do
    released =
      json
      |> Map.get("releases", [])
      |> Enum.find(%{}, &(&1["version"] == version))
      |> Map.get("inserted_at")

    %{
      latest: version,
      released_at: released,
      downloads: get_in(json, ["downloads", "all"]),
      recent: get_in(json, ["downloads", "recent"])
    }
  end

  defp reading(_json), do: %{error: "hex.pm publishes no stable release of it"}

  # :httpc, which OTP already carries and `Console.Installers` already
  # uses for the same host.
  defp get(url) do
    headers = [{~c"user-agent", ~c"dockerized-elixir-workbench"}]

    case :httpc.request(:get, {String.to_charlist(url), headers}, [timeout: @timeout],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, 404, _}, _, _}} -> {:error, "hex.pm has no such package"}
      {:ok, {{_, code, _}, _, _}} -> {:error, "hex.pm answered #{code}"}
      {:error, reason} -> {:error, "hex.pm could not be reached: #{inspect(reason)}"}
    end
  end

  @doc """
  How long ago, in the words the console uses elsewhere: `today`,
  `3 days ago`, `8 months ago`, `2 years ago`. `nil` for a date hex
  did not give.
  """
  @spec ago(String.t() | nil, DateTime.t()) :: String.t() | nil
  def ago(nil, _now), do: nil

  def ago(iso, now) do
    case DateTime.from_iso8601(iso) do
      {:ok, then, _} -> said(DateTime.diff(now, then, :day))
      _ -> nil
    end
  end

  defp said(days) when days <= 0, do: "today"
  defp said(1), do: "yesterday"
  defp said(days) when days < 31, do: "#{days} days ago"
  defp said(days) when days < 365, do: "#{div(days, 30)} months ago"
  defp said(days) when days < 730, do: "a year ago"
  defp said(days), do: "#{div(days, 365)} years ago"
end
