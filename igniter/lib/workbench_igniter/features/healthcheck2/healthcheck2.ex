defmodule WorkbenchIgniter.Features.Healthcheck2 do
  @moduledoc """
  Liveness and readiness probes as a plug mounted first in the endpoint.

  Installed on demand with `mix workbench.install.healthcheck2`
  (`wb.sh add healthcheck2`). It is the vanilla counterpart of
  `healthcheck` (the chiefs_setup pick):
  where that one is a controller behind the router, with a JSON body
  that grows in dev and a Swagger entry, this one is what an orchestrator
  consumes and nothing more.

  ## Why a plug, and why first

  A probe is called every few seconds per instance for the life of the
  deployment. Placed as the first plug of `MyAppWeb.Endpoint` it is
  answered before `Plug.Static`, `Plug.SSL`, the logger, the telemetry,
  the parsers, the session and the router run: no log line per probe, no
  telemetry event, no session cookie, and no `301` from `force_ssl` when
  the probe arrives in plain HTTP on the internal port.

  ## Why two routes

  Kubernetes, Fly.io and AWS ECS all decide something different on a
  failed probe — restart the container, take it out of the balancer,
  keep waiting — so the check is split by consequence:

  * `/live` answers 200 while the VM answers. It touches nothing else:
    restarting the container does not fix a database that is down.
  * `/ready` runs `SELECT 1` on the repo with a one-second timeout and
    answers 503 when it fails, so the instance stops receiving traffic
    without being killed.

  A project without a repo (`--no-ecto`) gets a `/ready` that answers
  like `/live`, with the check left as the obvious place to extend.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.healthcheck2 --path /health"

  @impl true
  def task, do: "workbench.install.healthcheck2"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      path:
        "Prefix of the two probe routes. Defaults to `/health` (`/health/live` and `/health/ready`)."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [path: :string],
      defaults: [path: "/health"]
    }
  end

  # The mark: the plug (the endpoint edit always prepends, so the whole
  # install is guarded by it).
  @impl true
  def installed?(igniter),
    do: Igniter.Project.Module.module_exists(igniter, plug_module(igniter))

  defp plug_module(igniter),
    do: Module.concat([Igniter.Libs.Phoenix.web_module(igniter), Plugs, Health])

  @impl true
  def console, do: [probes: [{"live", "{path}/live"}, {"ready", "{path}/ready"}]]

  # What the project carries: the prefix, read off the plug it installed.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    path = "lib/#{app_name}_web/plugs/health.ex"

    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

      case Regex.run(~r/Keyword\.get\(opts, :path, "([^"]+)"\)/, content) do
        [_, prefix] -> {%{path: prefix}, igniter}
        nil -> {%{}, igniter}
      end
    else
      {%{}, igniter}
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    path = normalize_path(igniter.args.options[:path])

    # Everything below is derived from the target project.
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    plug = plug_module(igniter)
    test_module = Module.concat([web_module, Plugs, HealthTest])
    endpoint = Module.concat(web_module, Endpoint)
    repo = Module.concat(app_module, Repo)
    # phx.new derives its directories from the app name, not the module
    # (app :lorem_3 -> Lorem3Web -> "lorem_3_web", not "lorem3_web").
    web_dir = "#{app_name}_web"

    {repo?, igniter} = Igniter.Project.Module.module_exists(igniter, repo)

    assigns = [
      web_module: inspect(web_module),
      path: path,
      repo: if(repo?, do: inspect(repo)),
      ready_note: ready_note(repo?, repo)
    ]

    # The endpoint edit always prepends, so the whole install is guarded
    # by the plug's existence to make re-runs a no-op.
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(plug)} already exists: healthcheck2 is already installed, skipping."
        )

      {false, igniter} ->
        igniter
        |> Igniter.Project.Module.create_module(
          plug,
          template("plug.eex", assigns),
          path: "lib/#{web_dir}/plugs/health.ex"
        )
        |> Igniter.Project.Module.create_module(
          test_module,
          template("plug_test.eex", assigns),
          path: "test/#{web_dir}/plugs/health_test.exs"
        )
        |> mount_first(endpoint, plug)
    end
  end

  # What `/ready` checks, for the plug's @moduledoc — wrapped as the
  # surrounding paragraph is, since the doc is prose the project keeps.
  # Ends with the newline EEx's trim collapses after the tag: the blank
  # line before the next paragraph survives.
  defp ready_note(true, repo) do
    """
    Runs `SELECT 1` on
      `#{inspect(repo)}` with a short timeout, so a saturated pool answers
      503 fast instead of hanging the probe.
    """
  end

  defp ready_note(false, _repo) do
    """
    The project has no
      repo to check, so it answers like liveness: add here the checks the
      application depends on.
    """
  end

  # "/health/", "health" -> "/health"; the plug appends "/live" and "/ready".
  defp normalize_path(path) do
    "/" <> (path |> String.trim("/") |> String.trim())
  end

  # The plug goes before the first `plug` call of the endpoint (Plug.Static
  # in a phx.new project). The `socket` declarations above it are not part
  # of the plug pipeline, so they can stay where they are.
  defp mount_first(igniter, endpoint, plug) do
    code = """
    # Workbench healthcheck: answer the probes before anything else runs.
    plug #{inspect(plug)}
    """

    Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
      case Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :plug, :any) do
        {:ok, zipper} ->
          {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :before)}

        :error ->
          # No plug at all in the endpoint: append it, it is still the only one.
          {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
      end
    end)
  end
end
