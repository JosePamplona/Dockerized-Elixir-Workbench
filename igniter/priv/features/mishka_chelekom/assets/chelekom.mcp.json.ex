defmodule Mix.Tasks.Chelekom.Mcp.Json do
  @shortdoc "Writes .mcp.json: Mishka Chelekom's MCP server, at the address it answers on here"

  @moduledoc """
  #{@shortdoc}

      mix chelekom.mcp.json

  The router forwards a path to Mishka Chelekom's MCP server while
  `dev_routes` is on — `/mishka-chelekom/mcp`, unless the project moved
  it; the task reads it off the router. An AI tool — Claude Code, Cursor, VS Code — finds
  it through a `.mcp.json` at the project's root, which needs the
  address, and the address depends on where the project runs:

    * run with Docker Compose, it is the port `docker-compose.yml`
      publishes the endpoint's port on (`4011:4000` is
      `http://localhost:4011/mishka-chelekom/mcp`);
    * run with `mix phx.server` on the host — no `docker-compose.yml`,
      or one that publishes no such port — it is the endpoint's own
      port.

  So the file is written by this task, off what the project says today,
  and is not kept in git: `.gitignore` lists it. Run it again when the
  published port changes.

  An existing `.mcp.json` keeps its other servers: the task adds or
  replaces the `mishka-chelekom` entry alone. One that is
  not a JSON object is left as it is, and the task says so.
  """

  use Mix.Task

  @file_name ".mcp.json"
  @compose "docker-compose.yml"
  @server "mishka-chelekom"
  @routers "lib/*_web/router.ex"

  @impl Mix.Task
  def run(_argv) do
    Mix.Task.run("app.config")

    inside = endpoint_port(Application.get_all_env(Mix.Project.config()[:app]))
    {port, said} = published(inside, read(@compose))
    url = "http://localhost:#{port}#{route!()}"

    case merged(read(@file_name), url) do
      {:ok, json} ->
        File.write!(@file_name, json)
        Mix.shell().info("#{@file_name}: #{@server} at #{url} (#{said})")

      {:error, why} ->
        Mix.raise("#{@file_name} #{why}: left as it is. The address is #{url}.")
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  defp route! do
    case @routers |> Path.wildcard() |> Enum.find_value(&route(File.read!(&1))) do
      nil ->
        Mix.raise(
          "No router under #{@routers} forwards to MishkaChelekom.MCP.Server: there is no address to write."
        )

      path ->
        path
    end
  end

  @doc false
  # The path a router's source forwards to the library's MCP server on,
  # with the formatter's parentheses or without; `nil` when it has none.
  def route(router) do
    forward =
      ~r/forward\(?\s*"([^"]+)",\s*Anubis\.Server\.Transport\.StreamableHTTP\.Plug,\s*server:\s*MishkaChelekom\.MCP\.Server/

    case Regex.run(forward, router, capture: :all_but_first) do
      [path] -> path
      nil -> nil
    end
  end

  @doc false
  # The port the endpoint listens on: the `http: [port: …]` of the one
  # entry of the app's configuration that has it, or Phoenix's own 4000.
  def endpoint_port(env) do
    Enum.find_value(env, 4000, fn {_key, value} ->
      with true <- Keyword.keyword?(value),
           http when is_list(http) <- value[:http],
           port when is_integer(port) <- http[:port] do
        port
      else
        _ -> nil
      end
    end)
  end

  @doc false
  # The port of the host a compose file publishes `inside` on, off its
  # `- HOST:INSIDE` line (an address before it, `/tcp` after it and
  # quotes around it are all Compose's to allow); `inside` itself when
  # there is no file or no such line.
  def published(inside, nil), do: {inside, "the endpoint's port: no #{@compose} here"}

  def published(inside, compose) do
    line = ~r/^\s*-\s*["']?(?:[\d.]+:)?(\d+):#{inside}(?:\/tcp)?["']?\s*(?:#.*)?$/m

    case Regex.run(line, compose, capture: :all_but_first) do
      [host] -> {String.to_integer(host), "published by #{@compose} for #{inside}"}
      nil -> {inside, "the endpoint's port: #{@compose} publishes none for #{inside}"}
    end
  end

  @doc false
  # The file's new content: what it had, with this server's entry added
  # or replaced.
  def merged(nil, url), do: merged("{}", url)

  def merged(current, url) do
    case Jason.decode(current) do
      {:ok, %{} = config} ->
        servers =
          case config["mcpServers"] do
            %{} = servers -> servers
            _ -> %{}
          end

        entry = %{"type" => "http", "url" => url}
        config = Map.put(config, "mcpServers", Map.put(servers, @server, entry))
        {:ok, Jason.encode!(config, pretty: true) <> "\n"}

      _ ->
        {:error, "is not a JSON object"}
    end
  end
end
