defmodule Mix.Tasks.Workbench.PlantAsset do
  use Mix.Task

  # No @shortdoc on purpose: internal plumbing, hidden from `mix help`.
  @moduledoc """
  Copies a feature asset into the project verbatim.

      mix workbench.plant_asset FEATURE ASSET TARGET

  Internal plumbing for binary assets (images, fonts): the igniter
  rewrite pipeline normalizes every file it writes
  (`String.trim_trailing/1` plus a final newline), which corrupts
  binaries. Installers compose this task via
  `WorkbenchIgniter.plant_binary_asset/4`, so the copy runs only after
  the patch set is confirmed and applied — dry-run semantics intact.
  """

  @doc false
  def run([feature, asset, target]) do
    source =
      :workbench_igniter
      |> :code.priv_dir()
      |> Path.join("features")
      |> Path.join(feature)
      |> Path.join(asset)

    File.mkdir_p!(Path.dirname(target))
    File.cp!(source, target)

    Mix.shell().info("* copying #{target}")
  end

  def run(_argv) do
    Mix.raise("Usage: mix workbench.plant_asset FEATURE ASSET TARGET")
  end
end
