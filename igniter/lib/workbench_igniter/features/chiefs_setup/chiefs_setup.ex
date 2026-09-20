defmodule WorkbenchIgniter.Features.ChiefsSetup do
  @moduledoc """
  The chief's setup: the collection cartridge that outfits a vanilla
  project with the workbench's picks.

  A *collection* is a cartridge whose installer inserts other
  cartridges: `members/1` is its recipe — the picks, in order, with the
  argv each installer gets. The one choice the collection owns is
  `--interface` (rest or graphql); everything else a member does is its
  own default. A member's fine-grained option is never re-exposed here:
  whoever needs it inserts the member cartridge directly.

  `wb.sh add chiefs_setup` expands the recipe (`mix workbench.expand`)
  and inserts each missing member as its own commit, so `eject` keeps
  reverting one cartridge alone. Run directly
  (`mix workbench.install.chiefs_setup`), it composes the members'
  installers into one patch set instead.
  """
  use WorkbenchIgniter.Feature

  @example "mix workbench.install.chiefs_setup --interface rest"

  @interfaces ~w(rest graphql)

  @impl true
  def archived,
    do:
      "2026-09-20: the Phoenix line's collection, and the Ash line takes no collection — enhancements and auth0 fight Ash's domain"

  @impl true
  def task, do: "workbench.install.chiefs_setup"

  # The picks, in insertion order — the order the old `workbench.setup`
  # composed them in, which the marks build on (health_endpoint autodetects
  # rest's OpenApi.Spec; auth0 would need enhancements' Schema). The
  # argv is the recipe: the flags that tell a member which *fellow
  # picks* ride along (exdoc's `--coveralls`), never a member option
  # surfaced as the collection's.
  @impl true
  def members(opts) do
    interface = opts[:interface] || "rest"

    [
      # The house's settings on a stock project.
      {"ansi", []},
      {"version_manager", []},
      {"toolchain", []},
      {"changelog", []},
      {"dashboard_extras", []},
      {"db_admin", []},
      {"credo", []},
      {"mock", []},
      {"test_doubles", []},
      {"exdebug", []},
      interface_member(interface),
      {"coveralls", ["--exdoc"]},
      {"exdoc", ["--coveralls"]},
      {"enhancements", ["--interface", interface, "--exdoc", "--health"]},
      {"health_endpoint", []}
    ]
  end

  defp interface_member("graphql"), do: {"graphql", []}
  defp interface_member(_rest), do: {"rest", ["--health"]}

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [interface: "The API the picks build: `rest` | `graphql`. Default: `rest`."]
  end

  @impl true
  def choices do
    [
      interface: [
        {"rest", "a JSON API with OpenApiSpex documentation"},
        {"graphql", "an Absinthe schema and resolvers"}
      ]
    ]
  end

  # Running it again inserts the picks that are missing; the choice made
  # at first insert stays (the other interface is never swapped in).
  @impl true
  def rerun, do: :adds

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: composed_tasks(),
      schema: [interface: :string],
      defaults: [interface: "rest"]
    }
  end

  defp composed_tasks do
    @interfaces
    |> Enum.flat_map(&members(interface: &1))
    |> Enum.map(fn {name, _argv} -> "workbench.install." <> name end)
    |> Enum.uniq()
  end

  # The mark is delegated: the collection is in when every fixed pick is
  # and one of the two interfaces is — so a project set up with graphql
  # answers true too.
  @impl true
  def installed?(igniter) do
    {interface_in, igniter} = interface_installed?(igniter)

    Enum.reduce(fixed_members(), {interface_in, igniter}, fn feature, {in?, igniter} ->
      {member_in, igniter} = feature.installed?(igniter)
      {in? and member_in, igniter}
    end)
  end

  # What the project carries of the choice: the interface that is in.
  @impl true
  def state(igniter) do
    Enum.reduce(@interfaces, {%{}, igniter}, fn name, {state, igniter} ->
      case WorkbenchIgniter.Features.named(name).installed?(igniter) do
        {true, igniter} -> {Map.put_new(state, :interface, name), igniter}
        {false, igniter} -> {state, igniter}
      end
    end)
  end

  defp fixed_members do
    for {name, _argv} <- members([]),
        name not in @interfaces,
        do: WorkbenchIgniter.Features.named(name)
  end

  defp interface_installed?(igniter) do
    Enum.reduce(@interfaces, {false, igniter}, fn name, {in?, igniter} ->
      {member_in, igniter} = WorkbenchIgniter.Features.named(name).installed?(igniter)
      {in? or member_in, igniter}
    end)
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options
    interface = opts[:interface] || "rest"

    if interface in @interfaces do
      Enum.reduce(members(opts), igniter, fn {name, argv}, igniter ->
        feature = WorkbenchIgniter.Features.named(name)
        Igniter.compose_task(igniter, feature.task(), argv)
      end)
    else
      Igniter.add_issue(
        igniter,
        "--interface must be one of #{Enum.join(@interfaces, ", ")}, got: #{interface}"
      )
    end
  end
end
