defmodule Console.GitHubTest do
  @moduledoc """
  What GitHub says of a package that comes from a repository there. The
  call is a function `read/2` takes, so the suite hands it GitHub's own
  answers — the shapes `releases/latest`, `tags` and a commit return —
  and never calls GitHub.
  """
  use ExUnit.Case, async: true

  alias Console.GitHub

  @api "https://api.github.com/repos/"

  test "the latest release and its day, and no downloads" do
    fetch = fn
      @api <> "saadeghi/daisyui/releases/latest" ->
        {:ok, ~s({"tag_name": "v5.5.20", "published_at": "2026-09-01T10:00:00Z", "draft": false})}
    end

    assert GitHub.read([{"daisyui", "saadeghi/daisyui"}], fetch) == %{
             "daisyui" => %{
               latest: "v5.5.20",
               released_at: "2026-09-01T10:00:00Z",
               downloads: nil
             }
           }
  end

  test "a repository that publishes tags and no releases: its newest tag, dated by its commit" do
    commit = @api <> "tailwindlabs/heroicons/commits/0435d4c"

    fetch = fn
      @api <> "tailwindlabs/heroicons/releases/latest" ->
        {:error, :not_found}

      @api <> "tailwindlabs/heroicons/tags?per_page=1" ->
        {:ok, ~s([{"name": "v2.2.0", "commit": {"sha": "0435d4c", "url": "#{commit}"}}])}

      ^commit ->
        {:ok, ~s({"commit": {"committer": {"date": "2024-11-18T12:00:00Z"}}})}
    end

    assert GitHub.read([{"heroicons", "tailwindlabs/heroicons"}], fetch) == %{
             "heroicons" => %{
               latest: "v2.2.0",
               released_at: "2024-11-18T12:00:00Z",
               downloads: nil
             }
           }
  end

  test "a repository that does not answer carries its reason" do
    fetch = fn
      @api <> "gone/away/releases/latest" ->
        {:error, :not_found}

      @api <> "gone/away/tags?per_page=1" ->
        {:error, :not_found}

      @api <> "busy/repo/releases/latest" ->
        {:error, "GitHub is limiting requests until 14:05 UTC"}
    end

    assert GitHub.read([{"gone", "gone/away"}, {"busy", "busy/repo"}], fetch) == %{
             "gone" => %{error: "GitHub has no such repository"},
             "busy" => %{error: "GitHub is limiting requests until 14:05 UTC"}
           }
  end

  test "the hour's allowance spent is said with the time it comes back" do
    headers = [{~c"x-ratelimit-remaining", ~c"0"}, {~c"x-ratelimit-reset", ~c"1790172300"}]
    assert GitHub.limited(headers) == "GitHub is limiting requests until 14:05 UTC"
    assert GitHub.limited([{~c"x-ratelimit-remaining", ~c"12"}]) == nil
  end
end
