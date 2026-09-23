defmodule Mix.Tasks.Workbench.Status do
  use Mix.Task

  @shortdoc "Says which workbench cartridges this project carries"

  @moduledoc """
  #{@shortdoc}

      mix workbench.status [--json]

  The catalog (`mix workbench.catalog`) with one more fact per cartridge:
  whether *this* project has it installed. Each cartridge answers for
  itself (`installed?/1`), off the same mark its installer's guard reads
  — the module, file or dependency whose presence makes a re-run a
  no-op — so what this prints and what `mix workbench.install.*` would
  skip are one and the same. It reads the project's source through
  Igniter; nothing is compiled or written.

  ## Options

  * `--json` - One JSON object, `{"app": ..., "phx": {...}, "cartridges": [...],
    "services": [...], "birth": {...} | null, "deployments": {...}}`
    — each cartridge carries `detected`, the defaults it would read off
    this project for the options it does not fix (`detect/1`), and
    `deps`, what it put in `mix.exs`: the box's own pin (`declared`),
    what the project asks for today (`pinned`) and what `mix.lock`
    resolved (`locked`), so an insert older than the box reads as the
    difference it is; `services` are the compose services the installed cartridges ask
    the workspace for (`postgres`, `pgadmin`, `grafana`…), what `mix workbench.compose`
    bakes in, and each installed cartridge carries `compose`: the services
    it brings, by their name in the file, with the port each `listens` on
    and the ones `published` on the host (`WorkbenchIgniter.Compose.brought/2`);
    `phx` is the project's shape in phx.new's terms: each capability,
    the database, the adapter, the flags that would generate it today,
    and `generator`: which `phx.new` made the project (`project`), where
    that is recorded (`source`: the workspace's `Dockerfile.local`, or
    `mix.exs` for a project generated outside the workbench), and which
    installer is at hand (`installer`). The base cartridges refuse when
    those two differ, so a console can say it before anyone presses
    Insert. `birth` is the same shape read off the first commit
    (`WorkbenchIgniter.Birth`): the sha, date and subject, `phx` as
    generation left it, and Dockerfile.local's stamps then — what the
    project was made with, never inferred; null for a project not born
    in a workspace. `deployments` is each compose file beside the project
    (`WorkbenchIgniter.Deployments`): baked, the services it declares,
    and whether it is in sync with what the cartridges ask for now, with
    what is stray or missing when it is not.
  """

  alias WorkbenchIgniter.Birth
  alias WorkbenchIgniter.Deployments
  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [json: :boolean])

    # A plain task, on purpose: Igniter's own would compile the project
    # first, and nothing here needs it — only the rewrite application
    # that reads the source.
    Application.ensure_all_started(:rewrite)

    %{
      app: app,
      phx: phx,
      cartridges: cartridges,
      services: services,
      birth: birth,
      deployments: deployments
    } =
      answer = read()

    if opts[:json] do
      IO.puts(Jason.encode!(answer, pretty: true))
    else
      {installed, missing} = Enum.split_with(cartridges, & &1.installed)

      IO.puts("Cartridges of #{app}: #{length(installed)} installed, #{length(missing)} not.")
      IO.puts("As phx.new would generate it today: mix phx.new . #{Enum.join(phx.flags, " ")}")
      IO.puts(generator_line(phx.generator))
      IO.puts(birth_line(birth))
      IO.puts("Services: " <> if(services == [], do: "none", else: Enum.join(services, ", ")))
      IO.puts("Deployments: " <> deployments_line(deployments))
      IO.puts("")

      for {title, list} <- [{"Installed", installed}, {"Not installed", missing}],
          list != [] do
        IO.puts(title <> "\n" <> indent(Mix.Tasks.Workbench.Catalog.table(list)) <> "\n")
      end
    end
  end

  @doc """
  The status as one map — `app`, `phx`, `cartridges`, `services` — read
  off the project's source through Igniter. What `--json` prints, and
  what the resident (`mix workbench.serve`) answers.
  """
  def read do
    app = Mix.Project.config()[:app]
    {cartridges, igniter} = Features.status(Igniter.new())
    {services, igniter} = Features.services(igniter)

    cartridges = with_deps(cartridges)

    # What each installed cartridge brings to the compose, asked of the
    # cartridge (`compose/1`): nobody downstream knows a service by name.
    cartridges =
      Enum.map(cartridges, fn cartridge ->
        feature = Enum.find(Features.catalog(), &(&1.name() == cartridge.name))

        Map.put(
          cartridge,
          :compose,
          if(cartridge.installed,
            do: WorkbenchIgniter.Compose.brought(feature, services),
            else: []
          )
        )
      end)

    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    {generator, _igniter} = WorkbenchIgniter.PhxDelta.generator(igniter)

    phx =
      %{facts | module: inspect(facts.module)}
      |> Map.put(:flags, WorkbenchIgniter.PhxDelta.flags(facts))
      |> Map.put(:generator, generator)

    birth =
      case Birth.read() do
        nil -> nil
        b -> put_in(b, [:phx, :module], inspect(b.phx.module))
      end

    %{
      app: app,
      phx: phx,
      cartridges: cartridges,
      deps: project_deps(),
      services: services,
      birth: birth,
      deployments: Deployments.read(File.cwd!(), services)
    }
  end

  # Every package the project carries, with what mix.exs asks for and
  # what mix.lock resolved. The cartridges' own readings are the same
  # two facts narrowed to what a box declares; this is the whole list,
  # for the packages nobody declares — a base cartridge's arrive inside
  # the phx.new delta, so what it brought is read off its insert commit
  # and matched against the project here.
  defp project_deps do
    pinned = pinned_deps()
    locked = Mix.Dep.Lock.read()

    for {name, requirement} <- pinned do
      %{name: to_string(name), pinned: requirement, locked: locked_version(locked[name])}
    end
  end

  # What each installed cartridge put in the project's mix.exs, beside
  # what the project does with it: `declared` is the box's own pin
  # (`deps/1`, given what the project carries of its options), `pinned`
  # is what mix.exs asks for today — the two differ on a project whose
  # insert is older than the box — and `locked` is the version
  # `mix.lock` resolved, which is the one the project runs. Both are
  # read here, where this task runs inside the project, and nowhere
  # else: the catalog carries only what a box declares.
  defp with_deps(cartridges) do
    pinned = pinned_deps()
    locked = Mix.Dep.Lock.read()

    Enum.map(cartridges, fn cartridge ->
      feature = Enum.find(Features.catalog(), &(&1.name() == cartridge.name))

      brought = if cartridge.installed and feature, do: feature.deps(cartridge.state), else: []

      Map.put(cartridge, :deps, for(dep <- brought, do: dep_reading(dep, pinned, locked)))
    end)
  end

  # mix.exs's own list: the package and the requirement it asks for,
  # which a dep given by path or git does not have. Read off the file
  # and not `Mix.Project.config()`, which is the project as it was when
  # Mix pushed it — in the resident (`workbench.serve`) that is the
  # project of an hour ago, and a package inserted since would read as
  # pinned by nobody.
  defp pinned_deps do
    case File.read("mix.exs") do
      {:ok, text} -> WorkbenchIgniter.MixFile.requirements(text)
      {:error, _} -> %{}
    end
  end

  defp dep_reading(dep, pinned, locked) do
    name = elem(dep, 0)

    %{
      name: to_string(name),
      declared: if(is_binary(elem(dep, 1)), do: elem(dep, 1)),
      pinned: Map.get(pinned, name),
      locked: locked_version(locked[name])
    }
  end

  # The lock's entry for a package from hex: `{:hex, :ex_doc, "0.40.4", …}`.
  # A package from git is locked to a commit and not to a version —
  # `{:git, url, sha, …}` — and a sha is not a version to read, nor one
  # hexdocs has a page for.
  defp locked_version(entry)
       when is_tuple(entry) and tuple_size(entry) > 2 and elem(entry, 0) == :hex do
    version = elem(entry, 2)
    if is_binary(version), do: version
  end

  defp locked_version(_entry), do: nil

  defp birth_line(nil),
    do: "Born: no first commit to read — not a project born in a workspace."

  defp birth_line(%{sha: sha, date: date, phx: phx}),
    do: "Born #{String.slice(sha, 0, 7)} (#{date}): mix phx.new . #{Enum.join(phx.flags, " ")}"

  defp deployments_line(deployments) do
    Enum.map_join([:dev, :prod, :scaled], " · ", fn deploy ->
      case deployments[deploy] do
        %{baked: false} ->
          "#{deploy} not baked"

        %{in_sync: true} ->
          "#{deploy} baked, in sync"

        %{stray: stray, missing: missing} ->
          "#{deploy} baked, out of sync (" <>
            Enum.join(Enum.map(stray, &("+" <> &1)) ++ Enum.map(missing, &("-" <> &1)), " ") <>
            ")"
      end
    end)
  end

  defp indent(text), do: text |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))

  # The generator, and whether the installer here is the same one — the
  # difference is what makes every base cartridge refuse.
  defp generator_line(%{project: nil}),
    do:
      "Generated by an unknown phx.new: the workspace carries no ARG PHX_NEW, and mix.exs's phoenix requirement is not the form phx.new writes."

  defp generator_line(%{project: v, source: source, installer: nil}),
    do: "Generated by phx.new #{v} (#{source}); no phx_new installer here to compare."

  defp generator_line(%{project: v, source: source, installer: v}),
    do: "Generated by phx.new #{v} (#{source}) — the installer here."

  defp generator_line(%{project: v, source: source, installer: i}),
    do:
      "Generated by phx.new #{v} (#{source}), but the installer here is #{i}: the base cartridges will refuse until the workspace's toolchain is rebuilt from its own Dockerfile.local (./wb.sh build)."
end
