defmodule Mix.Tasks.Workbench.Expand do
  use Mix.Task

  @shortdoc "Expands a cartridge into the inserts `wb.sh add` runs"

  @moduledoc """
  #{@shortdoc}

      mix workbench.expand [--archived] CARTRIDGE [OPTIONS]

  The planning half of `wb.sh add`: one `plan> <name> [argv]` line per
  install to run, in order — the shell runs each as its own container
  and commit. A plain cartridge expands to itself, options passed
  through untouched. A collection (chiefs_setup) expands to its
  `members/1` — the recipe its options choose — minus the members this
  project already carries, read off each member's own mark
  (`installed?/1`), so re-adding a collection only inserts what is
  missing. A fully carried collection expands to nothing.

  Everything but the `plan> ` lines is progress noise from mix: the
  shell filters by the prefix.

  A cartridge that is not to be offered is refused here, where the plan
  is drawn, and not by its installer: `pending` has none to run, and
  `archived` still has a working one — the box was retired, not broken.
  So the retired refusal names `--archived`, which draws the plan
  anyway for whoever is rebuilding an old project on purpose. There is
  no such flag for a pending box: nothing to force.
  """

  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(["--archived" | argv]), do: run(argv, true)
  def run(argv), do: run(argv, false)

  defp run([], _forced),
    do: Mix.raise("Missing cartridge name. Try: mix workbench.expand chiefs_setup")

  defp run([name | argv], forced) do
    feature = Features.named(name) || Mix.raise("Unknown cartridge: #{name}")

    if feature.pending?() do
      Mix.raise("The #{name} cartridge is pending: its installer is not done yet.")
    end

    if feature.archived?() and not forced do
      Mix.raise(
        "The #{name} cartridge is archived (#{feature.archived()}). It is not offered " <>
          "for new projects; its papers stay on the shelf. To insert it anyway: " <>
          "./wb.sh add --archived #{name}"
      )
    end

    for {member, member_argv} <- plan(feature, argv) do
      IO.puts(Enum.join(["plan>", member | member_argv], " "))
    end

    :ok
  end

  @doc "The plan: `[{name, argv}]`, what `wb.sh add` runs for this cartridge with these options."
  def plan(feature, argv) do
    # Probed with no options: a plain cartridge has no members whatever
    # the options say, and expands to itself, argv untouched.
    case feature.members([]) do
      [] ->
        [{feature.name(), argv}]

      _members ->
        members = feature.members(collection_opts(feature, argv))

        # Reading the members' marks needs the project source, not a
        # compile: same plain-task read as `mix workbench.status`.
        Application.ensure_all_started(:rewrite)

        {plan, _igniter} = Enum.flat_map_reduce(members, Igniter.new(), &missing_member/2)

        plan
    end
  end

  # A member already in the project leaves the plan; one missing joins it.
  defp missing_member({name, member_argv}, igniter) do
    case Features.named(name).installed?(igniter) do
      {true, igniter} -> {[], igniter}
      {false, igniter} -> {[{name, member_argv}], igniter}
    end
  end

  # A collection's options, parsed with its own schema and defaults and
  # checked against its closed choice lists — the same lists its
  # installer validates against, so the plan and the install can never
  # disagree on what a value means.
  defp collection_opts(feature, argv) do
    %{schema: schema, defaults: defaults} = feature.info([], nil)
    {opts, _args, _invalid} = OptionParser.parse(argv, switches: schema || [])
    opts = Keyword.merge(defaults || [], opts)

    for {key, values} <- feature.choices(),
        is_list(values),
        chosen = opts[key],
        chosen not in values(values) do
      Mix.raise("--#{key} must be one of #{Enum.join(values(values), ", ")}, got: #{chosen}")
    end

    opts
  end

  defp values([{group, list} | _] = groups) when is_atom(group) and is_list(list),
    do: Enum.flat_map(groups, fn {_group, list} -> values(list) end)

  defp values(values) do
    Enum.map(values, fn
      {value, _doc} -> value
      {value, _doc, _requires} -> value
      value -> value
    end)
  end
end
