defmodule ConsoleWeb.Band do
  @moduledoc """
  The band's middle: what the console is doing, as a dot and a word,
  and the errands — what it is fetching from outside — that word names.
  And the row that keeps the band company when the console was started
  for something other than what `config.conf` names now.
  """
  use Phoenix.Component

  @doc """
  The console was started for another workspace, or for a project by
  another name: a row across the frame, against the band, since
  2026-09-27 — it was a note inside the rail until then, which is a
  local place for the one condition true of the whole console at once.

  What it says depends on which of the two it is, because they are not
  the same thing and only one of them is about volumes:

    * another workspace — the console has that directory bind-mounted,
      and this one is not in the container at all;
    * the same workspace, another name — the console holds that name's
      build volumes, `<name>_build` and `<name>_deps`, which are the
      ones the compose of the project it was started for owns. The
      project here owns others.

  Either way a job's mix and git run in a container of their own, which
  is slower and nothing else: nothing is disabled with this. Starting
  again binds the console to this workspace, on the same address.
  """
  attr :rebind, :map,
    required: true,
    doc: "the mount as `Console.Workbench.rebind/0` reads it, `moved` and all"

  def rebind(assigns) do
    assigns = assign(assigns, moved?: assigns.rebind.moved)

    ~H"""
    <div class="rebind" role="status">
      <span class="what">
        <b>Jobs run in a container of their own — slower.</b>
        <%= if @moved? do %>
          This console was started for the workspace <span class="mono">{@rebind.workspace}</span>
          and has that one mounted, not this one, so mix and git cannot run in it.
        <% else %>
          This console was started for <span class="mono">{@rebind.project}</span>,
          and holds that project's build volumes — <span class="mono">{@rebind.project}_build</span>
          and <span class="mono">{@rebind.project}_deps</span>. The project here owns
          others, so mix and git cannot run in it.
        <% end %>
        Starting again binds it to this workspace, on the same address.
      </span>
      <ConsoleWeb.Refs.job_button
        label="Start again"
        class="mini"
        args="console up"
        title="./wb.sh console up — the console comes up again for this workspace, on the same address; this page reconnects on its own"
      />
    </div>
    """
  end

  @doc """
  What the console is doing, in the band's middle: a dot and a word.

  One place, always in front — the tray is per screen and the rail can be
  hidden. It is the chip's grammar minus the plate: nobody presses this,
  so it has no box. Mono in
  lower case, because everything here is read off the machine.

  The order is the order of what matters: your word first, since it is the
  only one the console cannot resolve alone; then what is running; then
  what is being read; then nothing, which still says so. The lost socket
  is not here at all — it is written in CSS, on the class LiveView puts on
  the page when the socket goes, because a server that cannot be reached
  cannot be the one to tell you.
  """
  attr :jobs, :list, required: true
  attr :reading, :any, required: true
  attr :errands, :list, default: [], doc: "what the console is fetching from outside, by name"

  def state(assigns) do
    assigns = assign(assigns, state: state_of(assigns.jobs, assigns.reading, assigns.errands))

    ~H"""
    <div class={["state", elem(@state, 0)]} aria-live="polite">
      <span class="w"><i class="dot"></i><span class="word">{elem(@state, 1)}</span></span>
    </div>
    """
  end

  defp state_of(jobs, reading, errands) do
    running = Enum.filter(jobs, &(&1.state == :running))

    cond do
      Enum.any?(jobs, &(&1.state == :pending)) -> {"warn", "waiting for your word"}
      running != [] -> running_word(running)
      # An errand out of the machine is said before the readings of it:
      # it is the one the reader pressed a button for, and the only thing
      # the console does that leaves the host at all. Saying it here is
      # what the band is for — the button spinning is what the hand sees,
      # this is what the room sees.
      errands != [] -> {"busy", "asking " <> Enum.join(errands, " and ") <> "…"}
      reading == :full -> {"busy", "reading the cartridges…"}
      reading -> {"busy", "reading…"}
      true -> {"idle", "idle"}
    end
  end

  # The two fields that go out to the internet, by the name of who they
  # are asking — the same word their button's title uses.
  def errands(assigns) do
    for {asking, who} <- [
          {assigns.stacks_asking, "docker hub"},
          {assigns.installers_asking, "hex"}
        ],
        asking,
        do: who
  end

  defp running_word([job]), do: {"busy", said(job.kind)}
  defp running_word(jobs), do: {"busy", "#{length(jobs)} jobs"}

  # A job in the band's words: the verb, and what it is about. `up dev`,
  # `add rest`, `delete` — the cmdline's own first two words, which is
  # what the reader typed or pressed, and never the whole line: the band
  # is not the tray.
  defp said({verb, nil}), do: to_string(verb)
  defp said({verb, what}), do: "#{verb} #{what}"
end
