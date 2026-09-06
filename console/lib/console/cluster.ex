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

  # The replica that answered, off the header nginx adds.
  defp served_by(headers) do
    for {k, v} <- headers,
        String.downcase(to_string(k)) == "x-served-by",
        do:
          to_string(v)
          |> Enum.join(", ")
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
