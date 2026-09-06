defmodule ConsoleWeb.Band do
  @moduledoc """
  The band's middle: what the console is doing, as a dot and a word,
  and the errands — what it is fetching from outside — that word names.
  """
  use Phoenix.Component

  @doc """
  What the console is doing, in the band's middle: a dot and a word.

  One place, always in front — the tray is per screen and the rail can be
  hidden. It is the chip's grammar minus the plate, the same move the
  probe made on the door: nobody presses this, so it has no box. Mono in
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
