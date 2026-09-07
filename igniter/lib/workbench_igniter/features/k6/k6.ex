defmodule WorkbenchIgniter.Features.K6 do
  @moduledoc """
  Load testing with k6: a starting script the project owns, `k6/smoke.js`,
  and the container that runs it — declared here (`services/1`, `"k6"`),
  rendered by `mix workbench.compose` under a compose profile `up` never
  starts, and run by `./wb.sh k6 [SCRIPT]` against the deployment that is
  up. The script reads its target from `BASE_URL`, which the compose sets
  for the topology k6 runs in: the app on localhost inside the pod, the
  balancer or the `app` alias on the scaled network. No dependency in
  the project, no requirement: a load test asks nothing of the code.
  """
  use WorkbenchIgniter.Feature

  embed_assets()

  @script "k6/smoke.js"

  @doc "The script this cartridge writes, and reads as its mark."
  def script_file, do: @script

  @impl true
  def task, do: "workbench.install.k6"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the script itself.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @script)

  # The container: grafana/k6 under `profiles: [tools]`, the project's
  # k6/ mounted read-only as /scripts, BASE_URL set per topology.
  @impl true
  def services(_state), do: ["k6"]

  @impl true
  def afterwards,
    do: "./wb.sh bake puts k6 into the workspace's compose; ./wb.sh k6 runs the smoke test."

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@script} already exists: k6 is in, skipping.")

      {false, igniter} ->
        Igniter.create_new_file(igniter, @script, asset("smoke.js"))
    end
  end
end
