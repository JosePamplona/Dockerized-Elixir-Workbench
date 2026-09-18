defmodule WorkbenchIgniter.Features.Html do
  @moduledoc """
  HTML — Phoenix.HTML, the browser pipeline, the layouts and core components, the page controller — for a project generated with `--no-html`; and LiveView on top of it, unless `--no-live`.

  A base cartridge: it names the `phx.new` flag and the mark, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  it at the installer's version, merged onto the project's files.

  LiveView is `phx.new`'s `--no-live`: not a capability of its own but a
  switch of html's, `live = html && live` in the generator, with no file
  of its own — a condition inside html's templates. So it is html's
  option here, on by default as it is in `phx.new`: `--live` brings it,
  `--no-live` leaves it out, and a second run on a project that has
  html without it adds it (`rerun: :adds`). Its mark is LiveView's own
  configuration in `config.exs`, the one block only `@live` writes.

  Re-running with nothing to add is a no-op.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.PhxDelta

  @impl true
  def task, do: "workbench.install.html"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      live:
        "LiveView on top of html: its configuration, the LiveSocket in `app.js` and the endpoint, the JS commands of the core components. On by default, as in `phx.new`; `--no-live` leaves it out, as `phx.new --no-live` does."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --no-live",
      schema: [live: :boolean],
      defaults: [live: true]
    }
  end

  # live is a piece: a second run with it adds it where html is in
  # without it, and never touches what is there.
  @impl true
  def rerun, do: :adds

  # The mark: the first thing --no-html leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :phoenix_html)

  @doc "What the project carries: whether LiveView is configured (`facts.live`, the one block only `--live` writes)."
  @impl true
  def state(igniter) do
    {facts, igniter} = PhxDelta.facts(igniter)
    {%{live: facts.live}, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    live? = Keyword.get(igniter.args.options, :live, true)
    {facts, igniter} = PhxDelta.facts(igniter)

    # html first, as phx.new generates it: the delta is taken against a
    # base whose live is off, so it brings html alone; then live on top
    # when asked and not there. `PhxDelta.insert/4` guards html by its
    # mark; live's guard is `facts.live`, read again once html is in,
    # since the html delta changes the files it reads.
    igniter =
      if facts.html,
        do: Igniter.add_notice(igniter, "html is in already: skipping."),
        else: PhxDelta.insert(igniter, __MODULE__, :html)

    cond do
      igniter.issues != [] -> igniter
      not live? -> igniter
      true -> add_live(igniter)
    end
  end

  defp add_live(igniter) do
    {facts, igniter} = PhxDelta.facts(igniter)

    if facts.live do
      Igniter.add_notice(igniter, "live is in already: skipping.")
    else
      igniter = PhxDelta.apply(igniter, :live, %{})

      # The LiveSocket lives in assets/js/app.js, which only esbuild
      # brings; phx.new's static placeholder for a project without a
      # bundler is a comment. Served, configured, and not connected to.
      if facts.esbuild or igniter.issues != [] do
        igniter
      else
        Igniter.add_notice(
          igniter,
          "live is in, but the browser has nothing to connect with: the LiveSocket lives in " <>
            "assets/js/app.js, which esbuild brings (./wb.sh add esbuild)."
        )
      end
    end
  end
end
