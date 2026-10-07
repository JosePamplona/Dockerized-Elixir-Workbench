defmodule Mix.Tasks.Workbench.IgniterInstall do
  use Mix.Task

  # No @shortdoc on purpose: internal plumbing, hidden from `mix help`.
  @moduledoc """
  `mix igniter.install`, ending in a failure when Igniter reports issues.

      mix workbench.igniter_install PACKAGE... [FLAG...]

  Internal plumbing: the ash cartridge queues this in place of
  `mix igniter.install`, with the same argv. When an installer it runs
  adds an issue, Igniter shows the issues, writes none of the
  installers' files — but the packages are already in `mix.exs` and
  `mix.lock`, added before the installers ran — and exits with zero:
  `Igniter.Util.Install.install/2` drops `do_or_dry_run`'s `:issues`.
  `wb.sh add` read that zero, on 2026-09-24, as an insert that landed and
  committed `Insert ash` holding nothing but the packages
  (`WorkbenchIgniter.Task` does the same for the workbench's own tasks).

  The result is lost, so the task listens for it: `igniter.install`
  runs under a shell that hands everything to the one in place and
  notes when Igniter prints its `Issues:` list, and then the task exits
  with `{:shutdown, 1}`, so `add` undoes the half-insert and refuses
  the commit.
  """

  defmodule Shell do
    @moduledoc false
    @behaviour Mix.Shell

    # The shell underneath and whether the issues were heard, kept in
    # an Agent: Mix's shell is global, and any process may print.
    @doc false
    def start(inner), do: Agent.start_link(fn -> {inner, false} end, name: __MODULE__)

    @doc false
    def issues?, do: Agent.get(__MODULE__, &elem(&1, 1))

    defp inner, do: Agent.get(__MODULE__, &elem(&1, 0))

    @impl true
    def print_app, do: inner().print_app()

    @impl true
    def info(message), do: inner().info(message)

    # Igniter's list of issues: `display_issues/1`, titled `Issues:`,
    # through `error/1` whenever the shell is not `Mix.Shell.IO`.
    @impl true
    def error(message) do
      if message |> IO.iodata_to_binary() |> String.contains?("Issues:"),
        do: Agent.update(__MODULE__, fn {inner, _} -> {inner, true} end)

      inner().error(message)
    end

    @impl true
    def prompt(message), do: inner().prompt(message)

    @impl true
    def yes?(message, options \\ []), do: inner().yes?(message, options)

    @impl true
    def cmd(command, options \\ []), do: inner().cmd(command, options)
  end

  defmodule Blind do
    @moduledoc false

    # An I/O device that answers as an 80×24 terminal and prints
    # nothing: the device of the Owl.LiveScreen `run/1` stands up when
    # there is no terminal. The widgets drawn on it (a spinner and its
    # last frame) go nowhere; everything else prints as before.

    @doc false
    def start, do: {:ok, spawn_link(&loop/0)}

    defp loop do
      receive do
        {:io_request, from, reply_as, request} ->
          send(from, {:io_reply, reply_as, reply(request)})
          loop()
      end
    end

    defp reply({:get_geometry, :columns}), do: 80
    defp reply({:get_geometry, :rows}), do: 24
    defp reply({:put_chars, _chars}), do: :ok
    defp reply({:put_chars, _encoding, _chars}), do: :ok
    defp reply({:put_chars, _mod, _fun, _args}), do: :ok
    defp reply({:put_chars, _encoding, _mod, _fun, _args}), do: :ok
    defp reply({:setopts, _opts}), do: :ok
    defp reply(_request), do: {:error, :enotsup}
  end

  @doc false
  def run(argv), do: watched("igniter.install", argv)

  @doc """
  Runs another package's Igniter task the way `run/1` runs
  `igniter.install`: under the listening shell, with a screen for its
  spinner, ending in a failure when it reports issues. For the
  cartridges whose install is a package's own task and not
  `igniter.install` (`workbench.mishka_components`).
  """
  @spec watched(String.t(), [String.t()]) :: :ok
  def watched(task, argv) do
    screen_for_owl()

    inner = Mix.shell()
    {:ok, _} = Shell.start(inner)
    Mix.shell(Shell)

    try do
      Mix.Task.run(task, argv)
    after
      Mix.shell(inner)
    end

    if Shell.issues?(), do: exit({:shutdown, 1}), else: :ok
  end

  # Installers that draw an Owl spinner (mishka_chelekom's) decide on
  # `IO.ANSI.enabled?()`, which the console turns on over a pipe for
  # colour (`WB_ANSI=always`). Owl's own LiveScreen does not start
  # without a terminal, and a spinner's stop waits for a render from
  # it that never comes: the installer dies of a 5 s timeout. With
  # colour and no terminal, a LiveScreen on `Blind` takes its name, so
  # the spinner draws nowhere and the colours stay. Owl starts first:
  # its supervisor would refuse a name already taken.
  defp screen_for_owl do
    with true <- IO.ANSI.enabled?(),
         {:error, _} <- :io.columns(),
         {:ok, _} <- Application.ensure_all_started(:owl),
         nil <- Process.whereis(Owl.LiveScreen) do
      {:ok, device} = Blind.start()
      {:ok, _} = Owl.LiveScreen.start_link(name: Owl.LiveScreen, device: device)
    end

    :ok
  end
end
