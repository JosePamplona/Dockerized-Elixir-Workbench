defmodule Console.Cluster do
  @moduledoc """
  The two questions the Cluster screen asks, run by the console itself.
  Who answers: four requests to the balancer's port, on the host the
  console reaches it by (`APP_HOST`, `host.docker.internal` inside its
  container, `localhost` on a host), reading `x-served-by`. Who is
  connected: `Node.list()` on the first replica through the release's
  `rpc`, on the socket the console holds.
  """

  def host, do: System.get_env("APP_HOST") || "localhost"

  def answers(port) do
    :inets.start()

    # Asked as the browser asks: the port is reached by the name the
    # console has for the host, but the request names `localhost`, the
    # host the reader's browser sends — and the one a prod endpoint's
    # force_ssl leaves alone. Under the console's own name the endpoint
    # would answer 301 to https, and the balancer's answer with it.
    for _ <- 1..4 do
      case :httpc.request(
             :head,
             {~c"http://#{host()}:#{port}/", [{~c"host", ~c"localhost"}]},
             [timeout: 3000],
             []
           ) do
        {:ok, {{_, code, _}, headers, _}} ->
          "HTTP #{code} · X-Served-By: #{served_by(headers)}"
          |> String.trim_trailing(" · X-Served-By: ")

        {:error, why} ->
          "no answer: #{inspect(why)}"
      end
    end
  end

  @doc """
  The replica that answered, off the header nginx adds — `""` where the
  answer carries none, which is what the line above trims away.

  `:httpc` hands its headers back as charlists, so each value is read as
  one and the join is over the *list of headers*, not over a value. It
  read `to_string(v) |> Enum.join(", ")` until 2026-09-26, which is
  `Enum.join/2` given a binary: it raised for every answer that carried
  the header — the only answer the probe exists to read — and never for
  one that did not, which is why nothing had seen it.
  """
  def served_by(headers) do
    headers
    |> Enum.filter(fn {k, _v} -> String.downcase(to_string(k)) == "x-served-by" end)
    |> Enum.map_join(", ", fn {_k, v} -> to_string(v) end)
  end

  def peers(project, service, app) do
    case System.cmd(
           "docker",
           [
             "compose",
             "--project-name",
             project,
             "exec",
             "-T",
             service,
             "/app/bin/#{app}",
             "rpc",
             "IO.inspect(Node.list())"
           ],
           stderr_to_stdout: true
         ) do
      {out, _} -> out |> Console.Workbench.strip() |> String.split("\n", trim: true)
    end
  end
end
