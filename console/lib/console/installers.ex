defmodule Console.Installers do
  @moduledoc """
  The Phoenix installers, read off hex: the stable `phx_new` releases and
  the Elixir each one declares.

  Read here and not through `wb.sh`, which is the line the console
  already draws elsewhere — the catalog is read in this BEAM, the logs
  are followed by this BEAM, a diff is git run from here. `wb.sh` is
  where the *actions* live, and where a fact about the workspace comes
  from; this is neither. Its twin `wb.sh stacks` is a verb for a reason
  that does not apply here: `stacks use TAG` writes three keys of
  `config.conf` at once, and no single `config set` can do that
  honestly. `PHX_NEW_VERSION` is one key, so choosing an installer is
  already `config set`'s job and there is nothing to act on.

  What this does **not** do is judge. Whether a stack can run a release
  is `stack_satisfies` in `wb.sh`, and `new` refuses on it — one rule,
  one place. The list carries each release's requirement and the page
  groups by it, so the reader compares three groups against one version
  instead of scanning twenty-five rows, and nothing here has an opinion
  that could come apart from the one that decides.

  hex has no bulk answer: its package endpoint lists every release with
  no requirement in it, and the repo registry carries a release's
  dependencies but not the Elixir it needs. Only the per-release
  endpoint knows (`meta.elixir`), so it is asked once per release — all
  at once, which is a quarter of a second for the twenty-five rather
  than the two and a half of one after another.
  """

  @package ~c"https://hex.pm/api/packages/phx_new"
  @release "https://hex.pm/api/packages/phx_new/releases/"

  # The same window `wb.sh` walks (PHX_NEW_CANDIDATES): enough to clear
  # the current minor line and reach the one below it. Beyond that the
  # releases are older than any stack the workbench builds.
  @candidates 25
  @timeout 15_000

  @doc """
  `{:ok, [%{"version" => v, "elixir" => requirement}]}`, newest first, or
  `{:error, why}`. A release hex answered for without a requirement
  carries `nil`: it is a release that declares no Elixir, not a failure.
  """
  def list do
    with {:ok, body} <- get(@package),
         {:ok, %{"releases" => releases}} <- Jason.decode(body) do
      versions =
        releases
        |> Enum.map(& &1["version"])
        |> Enum.filter(&(is_binary(&1) and not String.contains?(&1, "-")))
        |> Enum.take(@candidates)

      {:ok, requirements(versions)}
    else
      {:error, why} -> {:error, why}
      _ -> {:error, "hex.pm answered something that is not the phx_new package"}
    end
  end

  # One request per release, all in flight together. A release that does
  # not answer is kept with no requirement rather than dropped: the list
  # is what hex publishes, and a hole in it is not a reason to hide the
  # version from the reader.
  defp requirements(versions) do
    versions
    |> Task.async_stream(&requirement/1, max_concurrency: 10, timeout: @timeout, on_timeout: :kill_task)
    |> Enum.zip(versions)
    |> Enum.map(fn
      {{:ok, requirement}, version} -> %{"version" => version, "elixir" => requirement}
      {_, version} -> %{"version" => version, "elixir" => nil}
    end)
  end

  defp requirement(version) do
    with {:ok, body} <- get(String.to_charlist(@release <> version)),
         {:ok, %{"meta" => %{"elixir" => requirement}}} <- Jason.decode(body) do
      requirement
    else
      _ -> nil
    end
  end

  # :httpc, which OTP already carries — the console has no HTTP client
  # and does not need one for two endpoints. Its charlists stay in here.
  defp get(url) do
    case :httpc.request(:get, {url, [{~c"user-agent", ~c"dockerized-elixir-workbench"}]}, [timeout: @timeout], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, code, _}, _, _}} -> {:error, "hex.pm answered #{code}"}
      {:error, reason} -> {:error, "hex.pm could not be reached: #{inspect(reason)}"}
    end
  end
end
