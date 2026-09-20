defmodule ConsoleWeb.Services do
  @moduledoc """
  What a compose service is, for whoever draws one — asked, never
  known. The console names no cartridge's service: a cartridge says
  what its services are (`compose/1`, in the igniter) and the status of
  the project carries it per cartridge, as `compose` — the name in the
  file, where it enters, the port it listens on, a `title`, a `role`,
  the `shells` a session on it can be, its `position` among the others.
  Every screen that draws a container asks here: its colour, its order,
  whether it can be entered and with what.

  Three services are no cartridge's and are known here instead: the
  skeleton's — the `app` (and its replicas `app1`…), the `pod` and the
  `balancer` (`WorkbenchIgniter.Compose`'s two templates).

  A colour is a **role**'s, not a service's: the vocabulary is the
  igniter's (`WorkbenchIgniter.ComposeFile.roles/0`, the words the
  clouds sort their own services by), the palette is the console's, and
  several roles share a token until one needs telling apart. A role
  this console has not heard of, or a container no cartridge brought,
  wears the plainest — `svc-network`.
  """

  @skeleton %{
    "app" => %{"service" => "app", "role" => "compute", "position" => 0, "shells" => []},
    "pod" => %{"service" => "pod", "role" => "network", "position" => 90, "shells" => []},
    "balancer" => %{
      "service" => "balancer",
      "role" => "network",
      "position" => 91,
      "shells" => []
    }
  }

  @tokens %{
    "compute" => "compute",
    "database" => "database",
    "cache" => "database",
    "storage" => "database",
    "search" => "database",
    "devtools" => "devtools",
    "identity" => "devtools",
    "observability" => "observability",
    "network" => "network",
    "messaging" => "network",
    "job" => "job"
  }

  @doc "Every service the project's cartridges bring, and the skeleton's three, by name."
  @spec all(map() | nil) :: %{String.t() => map()}
  def all(status) do
    for c <- get_in(status || %{}, ["project", "cartridges"]) || [],
        b <- c["compose"] || [],
        into: @skeleton,
        do: {b["service"], b}
  end

  @doc "One service's record, a replica read as the app (`app3`); `nil` for a container nobody brought."
  @spec get(map() | nil, String.t() | nil) :: map() | nil
  def get(_status, nil), do: nil
  def get(status, service), do: all(status)[base(service)]

  defp base(service), do: if(service =~ ~r/^app\d+$/, do: "app", else: service)

  @doc "The CSS colour a service is drawn in: its role's, the balancer told apart from the pod."
  @spec color(map() | nil, String.t() | nil) :: String.t()
  def color(_status, "balancer"), do: "var(--svc-balancer)"
  def color(status, service), do: role_color(get(status, service)["role"])

  @doc """
  The CSS colour of a role, for a drawer that already knows one.

  The same step `color/2` ends in, reachable on its own: that one finds
  the role by asking the project, and the project only knows the
  cartridges it carries. A box on the shelf brings its services' roles
  with it (the catalog's `offers`), and drawing those through `color/2`
  painted every one of them the plainest — a shelf full of databases
  and dashboards in the colour of network.
  """
  @spec role_color(String.t() | nil) :: String.t()
  def role_color(role), do: "var(--svc-#{Map.get(@tokens, role, "network")})"

  @doc "The colour of every service known now, by name — what the logs' hook paints with, in the browser."
  @spec colors(map() | nil) :: %{String.t() => String.t()}
  def colors(status), do: Map.new(all(status), fn {name, _} -> {name, color(status, name)} end)

  @doc "Where a service sits among the others: the compose's own order, a stranger last."
  @spec position(map() | nil, String.t() | nil) :: integer()
  def position(status, service), do: get(status, service)["position"] || 99

  @doc "The sessions a service's container can be, as `{label, argv}`; none for one nobody enters."
  @spec shells(map() | nil, String.t()) :: [{String.t(), [String.t()]}]
  def shells(status, service) do
    for s <- get(status, service)["shells"] || [], do: {s["label"], s["command"]}
  end

  @doc """
  The prompt a session shows: for a shell, who and where the container
  says a session is (`homes`, in the status: the user and the working
  directory its image declares — an empty user is root's, as `docker
  exec` has it); for anything else, the command's own name. Derived,
  never written down per service.
  """
  @spec prompt(map() | nil, String.t(), String.t(), String.t() | nil) :: String.t()
  def prompt(status, service, shell, workdir \\ nil)

  def prompt(status, service, shell, workdir) when shell in ["sh", "bash"] do
    home = get_in(status || %{}, ["homes", service]) || %{}
    user = home["user"] |> to_string() |> String.split(":") |> hd()
    user = if user in ["", "0"], do: "root", else: user
    dir = workdir || presence(home["workdir"]) || "/"
    "#{user}@#{service}:#{dir}#{if user == "root", do: "#", else: "$"} "
  end

  def prompt(_status, _service, shell, _workdir), do: "#{shell}> "

  @doc """
  The images of the house's services, without tags — off the igniter's
  skeletons and catalog (`WorkbenchIgniter.Compose.images/0`), read once:
  the catalog is the workbench's, and does not change while this runs.
  """
  @spec images() :: [String.t()]
  def images do
    case :persistent_term.get({__MODULE__, :images}, nil) do
      nil ->
        images = WorkbenchIgniter.Compose.images()
        :persistent_term.put({__MODULE__, :images}, images)
        images

      images ->
        images
    end
  end

  defp presence(v) when v in [nil, ""], do: nil
  defp presence(v), do: v
end
