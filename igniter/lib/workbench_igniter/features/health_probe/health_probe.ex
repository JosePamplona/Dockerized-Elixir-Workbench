defmodule WorkbenchIgniter.Features.HealthProbe do
  @moduledoc """
  Liveness and readiness probes as a plug mounted first in the endpoint.

  Installed on demand with `mix workbench.install.health_probe`
  (`wb.sh add health_probe`). It is the platform's counterpart of
  `health_endpoint`: where that one is a controller behind the router, with
  a JSON body that grows in dev and a Swagger entry, this one is what an
  orchestrator consumes and nothing more.

  ## Why a plug, and why first

  A probe is called every few seconds per instance for the life of the
  deployment. Placed as the first plug of `MyAppWeb.Endpoint` it is
  answered before `Plug.Static`, the logger, the telemetry, the parsers,
  the session and the router run: no log line per probe, no telemetry
  event, no session cookie.

  `Plug.SSL` is not among them: `force_ssl`, on in `prod.exs` since
  Phoenix 1.8.2, plugs it inside `use Phoenix.Endpoint`, ahead of every
  plug of the project's, and a probe in plain HTTP on the pod's address
  would get a `301`. When `prod.exs` sets `force_ssl`, the installer
  lists both routes in its `exclude: [paths: …]` (Plug 1.19).

  ## Why two routes

  Kubernetes, Fly.io and AWS ECS all decide something different on a
  failed probe — restart the container, take it out of the balancer,
  keep waiting — so the check is split by consequence:

  * `/live` answers 200 while the VM answers. It touches nothing else:
    restarting the container does not fix a database that is down.
  * `/ready` runs `SELECT 1` on the repo with a 500 ms timeout and
    answers 503 when it fails, so the instance stops receiving traffic
    without being killed.

  A project without a repo (`--no-ecto`) gets a `/ready` that answers
  like `/live`, with the check left as the obvious place to extend.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.health_probe --path /health"

  @impl true
  def task, do: "workbench.install.health_probe"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      path:
        "Prefix of the two probe routes. Defaults to `/health` (`/health/live` and `/health/ready`); `/` for none (`/live` and `/ready`)."
    ]
  end

  # The prefix the two probes answer under: path segments, whatever
  # slashes are put around them (`normalize_path/1` trims those).
  @impl true
  def formats, do: [path: :route]

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
  def console, do: [doors: [{"live", "{path}/live"}, {"ready", "{path}/ready"}]]

  # What the project carries: the prefix, read off the plug it installed.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    path = "lib/#{app_name}_web/plugs/health.ex"

    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

      # `[^"]*`: the root is the empty prefix.
      case Regex.run(~r/Keyword\.get\(opts, :path, "([^"]*)"\)/, content) do
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
          "#{inspect(plug)} already exists: health_probe is already installed, skipping."
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
        |> exclude_from_force_ssl(app_name, endpoint, path)
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

  # "/health/", "health" -> "/health"; the plug appends "/live" and
  # "/ready". The root — "/" — is no prefix at all: the probes are
  # "/live" and "/ready", where "/" <> "" had them at "//live", which
  # no request ever asks for (2026-09-17, found by calling the plug).
  defp normalize_path(path) do
    case path |> String.trim() |> String.trim("/") do
      "" -> ""
      prefix -> "/" <> prefix
    end
  end

  # The plug goes before the first `plug` call of the endpoint (Plug.Static
  # in a phx.new project). The `socket` declarations above it are not part
  # of the plug pipeline, so they can stay where they are.
  defp mount_first(igniter, endpoint, plug) do
    code = """
    # Workbench health probe: answer the probes before anything else runs.
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

  # `use Phoenix.Endpoint` plugs Plug.SSL before any plug of the
  # project's, so mounting first does not get ahead of `force_ssl`, which
  # phx.new turns on in prod.exs since Phoenix 1.8.2: a probe in plain
  # HTTP on the pod's address got a 301. Plug.SSL's own way out (Plug
  # 1.19) is `exclude: [paths: …]`, matched against the whole path, so
  # both probes are listed. Without `force_ssl` nothing is written.
  #
  # The edit goes into the `config` call that holds `force_ssl`: a
  # project with assets has two for the endpoint (`cache_static_manifest`
  # first), and Igniter.Project.Config.configure wrote a nested key into
  # the first one — right once Config merged them, but away from where a
  # reader looks (2026-10-20, found live).
  defp exclude_from_force_ssl(igniter, app_name, endpoint, path) do
    probes = [path <> "/live", path <> "/ready"]
    file = "config/prod.exs"

    if Igniter.exists?(igniter, file) do
      Igniter.update_elixir_file(igniter, file, &exclude_in_block(&1, app_name, endpoint, probes))
    else
      igniter
    end
  end

  # No `config` call sets `force_ssl`: the file is left as it is.
  defp exclude_in_block(zipper, app_name, endpoint, probes) do
    with {:ok, call} <-
           Igniter.Code.Function.move_to_function_call(
             zipper,
             :config,
             3,
             &sets_force_ssl?(&1, app_name, endpoint)
           ),
         {:ok, opts} <- Igniter.Code.Function.move_to_nth_argument(call, 2) do
      exclude_probes(opts, probes)
    else
      _ -> {:ok, zipper}
    end
  end

  defp sets_force_ssl?(call, app_name, endpoint) do
    Igniter.Code.Function.argument_equals?(call, 0, app_name) and
      Igniter.Code.Function.argument_equals?(call, 1, endpoint) and
      Igniter.Code.Function.argument_matches_predicate?(
        call,
        2,
        &Igniter.Code.Keyword.keyword_has_path?(&1, [:force_ssl])
      )
  end

  defp exclude_probes(opts, probes) do
    if Igniter.Code.Keyword.keyword_has_path?(opts, [:force_ssl, :exclude]) do
      Igniter.Code.Keyword.put_in_keyword(
        opts,
        [:force_ssl, :exclude, :paths],
        probes,
        &append_probes(&1, probes)
      )
    else
      # A new `exclude` replaces Plug.SSL's default, so the default
      # hosts are written back beside the probes.
      Igniter.Code.Keyword.put_in_keyword(opts, [:force_ssl, :exclude],
        paths: probes,
        hosts: ["localhost", "127.0.0.1"]
      )
    end
  end

  # An `exclude: [paths: […]]` the project already has keeps its entries.
  defp append_probes(zipper, probes) do
    Enum.reduce_while(probes, {:ok, zipper}, fn probe, {:ok, zipper} ->
      case Igniter.Code.List.append_new_to_list(zipper, probe) do
        {:ok, zipper} -> {:cont, {:ok, zipper}}
        :error -> {:halt, :error}
      end
    end)
  end
end
