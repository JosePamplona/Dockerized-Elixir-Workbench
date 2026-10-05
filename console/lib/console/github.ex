defmodule Console.GitHub do
  @moduledoc """
  What GitHub says of a package that comes from a repository there
  (`github:` in `mix.exs`, or a `git:` url on github.com): its latest
  release and when it was published — the two hex answers for a
  package on hex.pm (`Console.Hex`), asked by the same button.

  The latest *release*, drafts and pre-releases left out, which is what
  `releases/latest` answers. A repository that publishes tags and no
  releases answers that with a 404; then its newest tag is the latest,
  and the date is its commit's. GitHub counts no downloads of a
  repository — only of the files attached to a release — so a reading
  carries none, and the table says why instead of a number.

  The same rules as hex's: never read on its own, one request per
  repository all in flight together, a repository that does not answer
  carries its reason. Without a token GitHub allows sixty requests an
  hour from one address; the button is pressed by a reader, and when
  the allowance runs out the row says until when.

  The call is a function this takes, `get/1` by default, so the suite
  hands it GitHub's own answers and never calls GitHub.
  """

  @api "https://api.github.com/repos/"
  @timeout 10_000

  @doc """
  `%{name => reading}` for each `{name, "owner/repo"}`, where a reading
  is `%{latest:, released_at:, downloads: nil}` or `%{error:}`.
  """
  @spec read([{String.t(), String.t()}], (String.t() -> {:ok, binary()} | {:error, term()})) ::
          %{String.t() => map()}
  def read(repos, fetch \\ &get/1) when is_list(repos) do
    repos = Enum.uniq(repos)

    repos
    |> Task.async_stream(fn {name, repo} -> {name, repository(repo, fetch)} end,
      max_concurrency: 10,
      timeout: 3 * @timeout + 1_000,
      on_timeout: :kill_task
    )
    |> Enum.zip(repos)
    |> Map.new(fn
      {{:ok, {name, reading}}, _asked} -> {name, reading}
      {_, {name, _repo}} -> {name, %{error: "GitHub did not answer in time"}}
    end)
  end

  defp repository(repo, fetch) do
    case json(fetch.(@api <> repo <> "/releases/latest")) do
      {:ok, %{"tag_name" => tag} = release} ->
        %{latest: tag, released_at: release["published_at"], downloads: nil}

      {:error, :not_found} ->
        newest_tag(repo, fetch)

      {:error, why} ->
        %{error: said(why)}
    end
  end

  # No release published: the newest tag, dated by its commit.
  defp newest_tag(repo, fetch) do
    with {:ok, [%{"name" => tag, "commit" => %{"url" => url}} | _]} <-
           json(fetch.(@api <> repo <> "/tags?per_page=1")),
         {:ok, commit} <- json(fetch.(url)) do
      %{latest: tag, released_at: get_in(commit, ["commit", "committer", "date"]), downloads: nil}
    else
      {:ok, []} -> %{error: "GitHub lists no release and no tag of it"}
      {:error, why} -> %{error: said(why)}
      _ -> %{error: "GitHub answered something that is not a tag"}
    end
  end

  defp json({:ok, body}) do
    case Jason.decode(body) do
      {:ok, json} -> {:ok, json}
      _ -> {:error, "GitHub answered something that is not JSON"}
    end
  end

  defp json(error), do: error

  defp said(:not_found), do: "GitHub has no such repository"
  defp said(why) when is_binary(why), do: why
  defp said(why), do: inspect(why)

  # :httpc, as `Console.Hex` asks hex.pm. A 404 is its own answer — no
  # release published — and a 403 or 429 with nothing remaining is the
  # hour's allowance spent, said with the time it comes back.
  defp get(url) do
    headers = [
      {~c"user-agent", ~c"dockerized-elixir-workbench"},
      {~c"accept", ~c"application/vnd.github+json"}
    ]

    case :httpc.request(:get, {String.to_charlist(url), headers}, [timeout: @timeout],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, 404, _}, _, _}} ->
        {:error, :not_found}

      {:ok, {{_, code, _}, headers, _}} when code in [403, 429] ->
        {:error, limited(headers) || "GitHub answered #{code}"}

      {:ok, {{_, code, _}, _, _}} ->
        {:error, "GitHub answered #{code}"}

      {:error, reason} ->
        {:error, "GitHub could not be reached: #{inspect(reason)}"}
    end
  end

  @doc false
  # The allowance spent: GitHub says when it comes back, in seconds
  # since the epoch; the reader is told the time, UTC.
  def limited(headers) do
    headers = Map.new(headers, fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)

    with "0" <- headers["x-ratelimit-remaining"],
         {reset, ""} <- Integer.parse(headers["x-ratelimit-reset"] || ""),
         {:ok, at} <- DateTime.from_unix(reset) do
      "GitHub is limiting requests until #{Calendar.strftime(at, "%H:%M")} UTC"
    else
      _ -> nil
    end
  end
end
