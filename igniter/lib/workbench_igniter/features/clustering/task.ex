defmodule Mix.Tasks.Workbench.Install.Clustering do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Clustering

  @shortdoc "Boots the production release as a distributed node for DNSCluster"

  @moduledoc """
  #{@shortdoc}

  `phx.new` already wires cluster discovery — the `:dns_cluster`
  dependency, the `DNSCluster` child in the supervision tree and the
  `DNS_CLUSTER_QUERY` read in `config/runtime.exs` — but leaves the
  release booting as a non-distributed node, which is what makes the
  discovery useless. This installer closes that gap:

  * creates the `mix release.init` templates the project lacks
    (`rel/vm.args.eex`, `rel/remote.vm.args.eex`, `rel/env.bat.eex`)
  * writes `rel/env.sh.eex` with `RELEASE_DISTRIBUTION=name` and a
    `RELEASE_NODE` resolved from the container IP at boot (an externally
    provided `RELEASE_NODE` wins)
  * declares `DNS_CLUSTER_QUERY` in `.env` and `.env.sample`

  Re-running it is a no-op: existing `rel/*.eex` files are kept, and both
  the distributed block and the environment variable are only added when
  absent.

  A workspace runs a single `app` container, so there is nothing to
  cluster with locally: this prepares the project for a multi-replica
  deployment. Every replica must run the same image — the release cookie
  is baked at `mix release` time and all nodes must share it.

  ## Example

      mix workbench.install.clustering

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Clustering)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Clustering.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Clustering.install(igniter)
end
