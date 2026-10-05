defmodule WorkbenchIgniter.ComposeFile do
  @moduledoc """
  The workspace's compose files as files: what is read off one, and
  what one is put together from. Everything that works on
  `docker-compose*.yml` as text lives here, as everything on `mix.exs`
  lives in `WorkbenchIgniter.MixFile`.

  Igniter has nothing for YAML, and a YAML library is not the tool: a
  compose the workbench writes says why it is shaped as it is, and a
  parse and an emit lose every comment. So a file is **read** by its
  lines — the services it declares, the ports it publishes — which is
  all anyone asks of it (`WorkbenchIgniter.Deployments`, the console's
  Record, `wb.sh`), and **written** from text: the topology's skeleton
  (`WorkbenchIgniter.Compose`'s templates) with what each service
  contributes set into its slots.

  ## What a service contributes

  A service is a cartridge's: the cartridge that needs it defines it
  (`WorkbenchIgniter.ComposeFile.Service`, returned by the cartridge's
  `compose/1`), whole — a compose knows a service in up to seven
  places, and all seven are the service's own:

    * `body` — its block under `services:`, comments included;
    * `ports` — the ports it publishes on the host. In the pod the `pod`
      container owns the network namespace and so publishes them all,
      and they go into its slot; on a bridge network the service
      publishes its own, in its body;
    * `app_waits` — what the app waits for because of it
      (`depends_on`, with a condition);
    * `app_volumes` and `app_environment` — what the app mounts and is
      told because of it (the SQLite file's volume; on the bridge
      network, where the database is);
    * `volumes` and `configs` — its entries under those top-level keys.

  `listens` is the port it answers on inside the deployment, published
  or not — what a reader of the workspace is told a closed door is.

  ## What a service is, to whoever draws it

  Nothing downstream knows a service by name — the console least of
  all: a cartridge may come from anywhere. What it needs to draw one,
  the service says: a `title` for a person; its `role`, one word of the
  vocabulary the clouds sort their own services by (`roles/0`), which a
  reader's palette turns into a colour; and the `shells` a session on
  its container can be — a label and the command, `[]` for a container
  nobody enters (k6 runs to completion). No prompt: a prompt is the
  user and the directory of the container, which the container says
  itself. The image needs no saying either: it is in the `body`
  (`image/1`).

  `position` says where it sits among the others, lower first — the
  database before what administers it, Prometheus before Grafana; at
  the same position, in the order gathered.

  `slots/3` gathers the contributions of a deployment's services, in
  the order given, into the text of each slot; the skeleton says where
  each goes.
  """

  defmodule Service do
    @moduledoc """
    What one service contributes to a compose file. Texts are YAML as it
    goes into the file, indented for where it goes (a `body` at two
    spaces, under `services:`), without a trailing newline.
    """

    @typedoc """
    A port the service publishes: `name` is the key its host port comes
    under (`:pgadmin`), `internal` the port it listens on, `default` the
    first host port to try, `comment` the lines that say what it is.
    """
    @type port_spec :: %{
            name: atom(),
            internal: pos_integer(),
            default: pos_integer(),
            comment: [String.t()]
          }

    @type t :: %__MODULE__{
            name: String.t(),
            deploys: [:dev | :prod | :scaled],
            ports: [port_spec()],
            position: integer(),
            title: String.t() | nil,
            role: String.t(),
            shells: [%{label: String.t(), command: [String.t()]}],
            listens: pos_integer() | nil,
            body: String.t(),
            app_waits: [{String.t(), String.t()}],
            app_volumes: String.t() | nil,
            app_environment: String.t() | nil,
            volumes: String.t() | nil,
            configs: String.t() | nil
          }

    @enforce_keys [:name, :body]
    defstruct name: nil,
              deploys: [:dev, :prod, :scaled],
              ports: [],
              position: 50,
              title: nil,
              role: "devtools",
              shells: [],
              listens: nil,
              body: nil,
              app_waits: [],
              app_volumes: nil,
              app_environment: nil,
              volumes: nil,
              configs: nil
  end

  @roles ~w(compute database cache storage messaging search network observability identity devtools job)

  @doc """
  The roles a service can have — what it is for, in the words the
  clouds use for their own (AWS's, Google's and Azure's product
  categories, Fly's extensions): `compute` runs the project's code;
  `database`, `cache`, `storage`, `search` and `messaging` keep and move
  its data; `network` lets traffic in and spreads it; `observability`
  watches; `identity` signs in and keeps secrets; `devtools` are for
  whoever develops (pgAdmin, Adminer, k6, a mailbox); a `job` runs once
  and ends (a migration). A vocabulary, not a palette: a reader maps
  several onto one colour, and one it does not know onto its plainest.
  """
  @spec roles() :: [String.t()]
  def roles, do: @roles

  @doc "The image a service's body runs, without its tag: `postgres`, `dpage/pgadmin4`; `nil` when it is built."
  @spec image(Service.t()) :: String.t() | nil
  def image(%Service{body: body}) do
    case Regex.run(~r/^    image: ([^\s:<]+(?::\d+\/[^\s:]+)?)(?::\S+)?$/m, body) do
      [_, repository] -> repository
      nil -> nil
    end
  end

  @typedoc "The text of each slot of a skeleton; `nil` where no service contributes."
  @type slots :: %{
          ports: String.t() | nil,
          services: String.t() | nil,
          app_waits: [{String.t(), String.t()}],
          app_volumes: String.t() | nil,
          app_environment: String.t() | nil,
          volumes: String.t() | nil,
          configs: String.t() | nil
        }

  @doc """
  The slots of a `deploy`'s file, off the services that enter it, in
  their order (`position`). `host_ports` has the host port of each published
  port by its name (`%{pgadmin: 5050}`) — chosen on the host, so handed
  over; one a service asks for and the map lacks is an error that names
  its flag (`WorkbenchIgniter.Compose` asks the host for it before).

  Bodies are a blank line apart, as services are in a file; port lines
  are indented for a service's `ports:` list (six spaces), each under
  its comment.
  """
  @spec slots([Service.t()], :dev | :prod | :scaled, %{atom() => pos_integer()}) ::
          {:ok, slots()} | {:error, String.t()}
  def slots(services, deploy, host_ports) do
    services = services |> Enum.filter(&(deploy in &1.deploys)) |> Enum.sort_by(& &1.position)
    asked = for s <- services, port <- s.ports, do: port

    case Enum.reject(asked, &is_integer(host_ports[&1.name])) do
      [] ->
        {:ok,
         %{
           ports: asked |> Enum.map(&port_lines(&1, host_ports[&1.name])) |> join("\n"),
           services: services |> Enum.map(& &1.body) |> join("\n\n"),
           app_waits: Enum.flat_map(services, & &1.app_waits),
           app_volumes: services |> Enum.map(& &1.app_volumes) |> join("\n"),
           app_environment: services |> Enum.map(& &1.app_environment) |> join("\n"),
           volumes: services |> Enum.map(& &1.volumes) |> join("\n"),
           configs: services |> Enum.map(& &1.configs) |> join("\n")
         }}

      missing ->
        {:error, "missing: " <> Enum.map_join(missing, ", ", &"--port #{&1.name}=PORT")}
    end
  end

  defp port_lines(port, host) do
    Enum.map_join(port.comment, "", &"      # #{&1}\n") <> "      - #{host}:#{port.internal}"
  end

  defp join(texts, separator) do
    case Enum.reject(texts, &(&1 in [nil, ""])) do
      [] -> nil
      texts -> Enum.join(texts, separator)
    end
  end

  @doc """
  The host ports the services ask for, each kept where the file already
  has it — a bake moves nothing — and `free.(default)` where it has
  not: the first free port from the service's default on, asked of the
  host. `text` is the deployment's file as it stands, or `nil`.
  """
  @spec host_ports([Service.t()], String.t() | nil, (pos_integer() -> pos_integer())) ::
          %{atom() => pos_integer()}
  def host_ports(services, text, free) do
    for service <- services, port <- service.ports, into: %{} do
      {port.name, (text && host_port(text, port.internal)) || free.(port.default)}
    end
  end

  @doc "The service names a compose file declares, in the file's order."
  @spec services(String.t()) :: [String.t()]
  def services(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({false, []}, fn line, {inside, acc} ->
      cond do
        line == "services:" ->
          {true, acc}

        # Another top-level key ends the block; an anchor (x-app: &app) never opened it.
        line != "" and not String.starts_with?(line, " ") ->
          {false, acc}

        inside and Regex.match?(~r/^  [a-z0-9_-]+:\s*$/, line) ->
          {true, [line |> String.trim() |> String.trim_trailing(":") | acc]}

        true ->
          {inside, acc}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  @doc """
  The ports each service publishes, off its `ports:` list: `- 4001:4000`
  as `{4001, 4000}`, host first, by the service that declares them — in
  the pod that is `pod`, whoever listens.
  """
  @spec published(String.t()) :: %{String.t() => [{pos_integer(), pos_integer()}]}
  def published(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({nil, false, %{}}, fn line, {service, inside, acc} ->
      cond do
        name = Regex.run(~r/^  ([a-z0-9_-]+):\s*$/, line) ->
          {Enum.at(name, 1), false, acc}

        Regex.match?(~r/^\s+ports:/, line) ->
          {service, true, acc}

        bind = inside && Regex.run(~r/^\s+- "?(\d+):(\d+)"?/, line) ->
          [_, host, container] = bind
          pair = {String.to_integer(host), String.to_integer(container)}
          {service, true, Map.update(acc, service, [pair], &(&1 ++ [pair]))}

        # A comment between two ports does not end the list; anything else does.
        inside and not Regex.match?(~r/^\s+#/, line) ->
          {service, false, acc}

        true ->
          {service, inside, acc}
      end
    end)
    |> elem(2)
  end

  @doc "The host port the file publishes `internal` on, whichever service declares it; `nil` for none."
  @spec host_port(String.t(), pos_integer()) :: pos_integer() | nil
  def host_port(text, internal) do
    text
    |> published()
    |> Enum.find_value(fn {_service, pairs} ->
      Enum.find_value(pairs, fn {host, container} -> container == internal && host end)
    end)
  end
end
