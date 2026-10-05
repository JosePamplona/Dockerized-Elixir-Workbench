defmodule ConsoleWeb.Doors do
  @moduledoc """
  The console calling the project's doors: every open route, once, and
  what each answered — the reading the Record (today the Birth paper,
  and the Deploy tab's rows) attaches to its addresses. The plan of the doors was a paper of its own until the
  Record took it over (2026-09-08); what is left here is the call.
  """

  @doc """
  What each address answered, called once: the status code as a chip's
  words and class — 2xx and 3xx good, 4xx warn, 5xx bad — or `no answer`.
  Every call has a short leash; the whole round waits for none of them
  past four seconds.

  The addresses are the reader's — `localhost` and the published port,
  what their browser opens — and the console calls the same door by the
  name it has for the host (`host/0`: `APP_HOST`, which is
  `host.docker.internal` inside its container, where `localhost` is the
  console itself), naming `localhost` in the request as the browser
  would, so a `force_ssl` endpoint answers as it answers the reader.
  """
  def read(hrefs) do
    Application.ensure_all_started(:inets)

    hrefs
    |> Task.async_stream(&{&1, call(&1)}, timeout: 4_000, on_timeout: :kill_task, ordered: false)
    |> Enum.map(fn
      {:ok, {href, read}} -> {href, read}
      {:exit, _} -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  @doc """
  The name the console has for the host the reader's browser calls
  `localhost`. It lived in `Console.Cluster` until that screen was
  retired on 2026-09-26, and this was its only other reader.
  """
  def host, do: System.get_env("APP_HOST") || "localhost"

  defp call(href) do
    url = String.replace_prefix(href, "http://localhost:", "http://#{host()}:")

    case :httpc.request(
           :get,
           {String.to_charlist(url), [{~c"host", ~c"localhost"}]},
           [timeout: 2_500, connect_timeout: 1_500, autoredirect: false],
           body_format: :binary
         ) do
      {:ok, {{_, code, _}, _, _}} -> {Integer.to_string(code), class(code)}
      {:error, _} -> {"no answer", "bad"}
    end
  end

  defp class(code) when code < 400, do: "good"
  defp class(code) when code < 500, do: "warn"
  defp class(_), do: "bad"
end
