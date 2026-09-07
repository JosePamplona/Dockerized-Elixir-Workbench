defmodule Console.Verbs do
  @moduledoc """
  The verbs of `wb.sh` the console runs as jobs, by name. A job is never
  a free-form line handed to the shell: the first word must be one of
  these, and what the verb is decides three things the page needs to
  know before the job runs and after it ends — its *kind* (the verb and
  what it is about: the deployment, the cartridge), whether it wants a
  confirmation first, and which reading of the workbench follows it.

  Three verbs are not jobs. `login` is a dialogue, and `logs`, `iex`
  and `bash` are streams that never end — they get a connection of
  their own, not a place in the queue. `console` is this page, and a
  job all the same: run from in here it starts the console again, for
  the workspace config.conf names now (see `Console.Workbench.rebind/0`).
  """

  @verbs ~w(new add eject bake commit up build stop down restart prune delete demo mix ps catalog status stacks expand config console help k6)

  @doc "Every verb a job may start with."
  def verbs, do: @verbs

  @typedoc "What a job is about: the verb, and the deployment or cartridge it names."
  @type kind :: {atom(), String.t() | nil}

  @doc """
  A command line — `up --deploy scaled`, `add rest --health` — into the
  argv `wb.sh` gets and the job's kind. The line is split on spaces;
  nothing here is a shell, so nothing is quoted or expanded.
  """
  @spec parse(String.t()) :: {:ok, kind(), [String.t()]} | {:error, String.t()}
  def parse(line) when is_binary(line) do
    case String.split(String.trim(line)) do
      [] ->
        {:error, "nothing to run"}

      [verb | rest] = args when verb in @verbs ->
        {:ok, kind(verb, rest), args}

      [verb | _] ->
        {:error, "#{verb} is not a verb the console runs (#{Enum.join(@verbs, ", ")})"}
    end
  end

  @doc "The kind of `wb.sh VERB ARGS`: the verb, and what it is about."
  @spec kind(String.t(), [String.t()]) :: kind()
  def kind(verb, args)
  def kind("add", [name | _]), do: {:insert, name}
  def kind("eject", [name | _]), do: {:eject, name}
  def kind("expand", args), do: {:expand, args |> Enum.reject(&(&1 == "--json")) |> List.first()}

  def kind(verb, args) when verb in ~w(up build stop down),
    do: {String.to_atom(verb), deployment(args)}

  # `restart app`, `restart --deploy scaled app2`: about the service.
  def kind("restart", args),
    do:
      {:restart,
       args
       |> Enum.reject(&(String.starts_with?(&1, "--") or &1 in ~w(dev prod scaled)))
       |> List.first()}

  # `k6`, `k6 --deploy scaled spike.js --vus 20`: about the script.
  def kind("k6", args),
    do:
      {:k6,
       args
       |> Enum.reject(&(String.starts_with?(&1, "--") or &1 in ~w(dev prod scaled)))
       |> List.first() || "smoke.js"}

  def kind(verb, _), do: {String.to_atom(verb), nil}

  # `--deploy TARGET`, or dev — the default every one of those verbs takes.
  defp deployment(args) do
    case Enum.drop_while(args, &(&1 != "--deploy")) do
      ["--deploy", target | _] -> target
      _ -> "dev"
    end
  end

  @doc """
  Whether the job must be confirmed before it runs. `delete` and
  `prune` always; `new` when the workspace already holds a project,
  since it overwrites every file in it. The console owns this gate: `wb.sh` runs under
  `--yes` and never asks.
  """
  @spec confirm?(kind(), boolean()) :: boolean()
  def confirm?({:delete, _}, _project?), do: true
  # Prune removes what other workspaces left: always asked, whatever it is about.
  def confirm?({:prune, _}, _project?), do: true
  def confirm?({:new, _}, project?), do: project?
  def confirm?(_, _), do: false

  @doc """
  What to read again once the job has ended. `:fast` is the status
  without the cartridges (containers, ports, git — tenths of a second);
  `:full` asks the cartridges too (a Mix boot); `:all` is a new
  workspace altogether — both, and the project's papers; `:config` is
  config.conf again, after a save; `:none` for the verbs that only read.
  """
  @spec reread(kind()) :: :fast | :full | :all | :config | :none
  def reread({:config, _}), do: :config

  def reread({verb, _}) when verb in [:up, :build, :stop, :down, :restart, :prune, :demo, :mix],
    do: :fast

  def reread({verb, _}) when verb in [:insert, :eject, :commit, :bake], do: :full
  def reread({verb, _}) when verb in [:new, :delete], do: :all
  def reread(_), do: :none
end
