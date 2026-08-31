defmodule WorkbenchIgniter.Features.Clustering do
  @moduledoc """
  Distributed Erlang for the production release, so the replicas find
  each other.

  Installed on demand with `mix workbench.install.clustering`
  (`wb.sh add clustering`).

  `phx.new` already ships nine tenths of this: `:dns_cluster` is a
  dependency, `{DNSCluster, query: ... || :ignore}` is in the supervision
  tree and `config/runtime.exs` reads `DNS_CLUSTER_QUERY` (inside its
  `:prod` block, so the variable is inert in dev). What it leaves open is
  the release booting as a *named distributed node*: without it
  `Node.connect/1` has nothing to work with, and DNSCluster itself logs

      node not running in distributed mode. Ensure the following exports
      are set in your rel/env.sh.eex file

  That file is what this cartridge owns, together with the three other
  `mix release.init` templates it needs to exist alongside.

  ## Variable ownership

  The `DNS_CLUSTER_QUERY`, `RELEASE_DISTRIBUTION` and `RELEASE_NODE`
  variables used to sit commented out in the `workbench.setup` `.env`
  template. They live here now, each where it belongs: the query in
  `.env`/`.env.sample`, the release pair in `rel/env.sh.eex`, where the
  node name can be resolved at boot.

  ## Scope

  A workspace runs a single `app` container, so there is nothing to
  cluster with here: this prepares the project for a real multi-replica
  deployment. All replicas must run the same image — the release cookie
  is baked at `mix release` time and every node has to share it.
  """
  use WorkbenchIgniter.Feature

  @example "mix workbench.install.clustering --dns-query my-app.internal"

  # The four rel/*.eex templates are Mix's own defaults. Mix exposes the
  # text of each one as a public (`@doc false`) function of the
  # `release.init` task, so they are generated from the running Elixir
  # instead of being copied into this repo and left to drift — and,
  # unlike composing the task, they land inside the patch set and show up
  # in the diff. `install/1` falls back to composing `mix release.init`
  # if a future Elixir drops those functions.
  @release_init Mix.Tasks.Release.Init
  @env_sh "rel/env.sh.eex"

  @impl true
  def task, do: "workbench.install.clustering"

  @impl true
  def console, do: [tabs: [:cluster]]

  @impl true
  def afterwards,
    do: "See it work: ./wb.sh up --deploy scaled brings the replicas up behind the balancer (the release image is rebuilt on each deploy)."

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      dns_query: "Value for `DNS_CLUSTER_QUERY`, the DNS name that resolves to the replica IPs. Defaults to `<app>.default.svc.cluster.local` (Kubernetes); on Fly.io it is usually `<app>.internal`."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [dns_query: :string],
      defaults: []
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    dns_query = igniter.args.options[:dns_query] || default_dns_query(app_name)

    igniter
    |> release_templates()
    |> distributed_env_sh()
    |> WorkbenchIgniter.env_entry(
      "Cluster discovery, queried by DNSCluster (:prod only).",
      ~s|DNS_CLUSTER_QUERY="#{dns_query}"|
    )
  end

  defp default_dns_query(app_name), do: "#{app_name}.default.svc.cluster.local"

  # --- rel/*.eex --------------------------------------------------------------

  # env.sh.eex is created by distributed_env_sh/1, which appends to it
  # when `new` (or a hand-run `mix release.init`) already left one behind.
  defp release_templates(igniter) do
    case release_init_texts() do
      {:ok, texts} ->
        Enum.reduce(texts, igniter, fn {path, content}, igniter ->
          Igniter.create_new_file(igniter, path, content, on_exists: :skip)
        end)

      :error ->
        igniter
        |> Igniter.add_task("release.init", [])
        |> Igniter.add_notice("""
        This Elixir no longer exposes the release.init templates: \
        `mix release.init` was queued instead, so rel/*.eex will appear \
        after the patch set is applied rather than in the diff below.\
        """)
    end
  end

  defp release_init_texts do
    module = @release_init

    exports? =
      Code.ensure_loaded?(module) and
        function_exported?(module, :vm_args_text, 1) and
        function_exported?(module, :env_bat_text, 0)

    if exports? do
      {:ok,
       %{
         "rel/vm.args.eex" => apply(module, :vm_args_text, [false]),
         "rel/remote.vm.args.eex" => apply(module, :vm_args_text, [true]),
         "rel/env.bat.eex" => apply(module, :env_bat_text, [])
       }}
    else
      :error
    end
  end

  defp env_sh_default do
    module = @release_init

    if Code.ensure_loaded?(module) and function_exported?(module, :env_text, 0),
      do: apply(module, :env_text, []),
      else: "#!/bin/sh\n"
  end

  # --- Distributed mode -------------------------------------------------------

  # RELEASE_NODE carries the container IP, unknown until the container
  # runs — which is why this belongs in the boot script and not in
  # runtime.exs. DNSCluster dials `<basename>@<ip>` for every IP the
  # query resolves, so the basename here must be the release name it
  # reads back from `node()`. POSIX sh only: the production runner image
  # has no bash. An externally provided RELEASE_NODE always wins.
  @distributed """
  # Workbench clustering: boot as a named distributed node.
  if [ -z "$RELEASE_NODE" ]; then
    RELEASE_NODE_IP="$(hostname -i 2>/dev/null)"
    RELEASE_NODE_IP="${RELEASE_NODE_IP%% *}"
    export RELEASE_NODE="$RELEASE_NAME@${RELEASE_NODE_IP:-127.0.0.1}"
  fi
  export RELEASE_DISTRIBUTION=name
  """

  defp distributed_env_sh(igniter) do
    if Igniter.exists?(igniter, @env_sh) do
      igniter
      |> Igniter.include_existing_file(@env_sh)
      |> Igniter.update_file(@env_sh, fn source ->
        Rewrite.Source.update(source, :content, &append_distributed/1)
      end)
    else
      Igniter.create_new_file(igniter, @env_sh, append_distributed(env_sh_default()))
    end
  end

  @marker "# Workbench clustering:"

  defp append_distributed(content) do
    if String.contains?(content, @marker),
      do: content,
      else: String.trim_trailing(content, "\n") <> "\n\n" <> @distributed
  end

  # The mark: the block above, in a file the cartridge does not own
  # (`new` may leave a rel/env.sh.eex behind before it is installed).
  # It is what wb.sh reads too, before baking the scaled compose.
  @impl true
  def installed?(igniter), do: marker_installed?(igniter, @env_sh, @marker)
end
