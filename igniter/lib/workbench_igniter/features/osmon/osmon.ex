defmodule WorkbenchIgniter.Features.Osmon do
  @moduledoc """
  OS process monitoring (`:os_mon`) — part of the trivial group toggled by
  `--enhance`. Dep-less: it patches `extra_applications` in `mix.exs`.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.osmon"

  @impl true
  def enabled?(opts), do: opts[:enhance] == true

  @impl true
  def enabled_by, do: :enhance

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: `:os_mon` in `extra_applications`, read off the same
  # `application/0` literal the installer patches.
  @impl true
  def installed?(igniter) do
    igniter = Igniter.include_existing_file(igniter, "mix.exs")

    zipper =
      igniter.rewrite
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:quoted)
      |> Sourceror.Zipper.zip()

    found? =
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :application, 0),
           {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :extra_applications) do
        zipper
        |> Igniter.Code.List.find_list_item_index(&Igniter.Code.Common.nodes_equal?(&1, :os_mon))
        |> is_integer()
      else
        _ -> false
      end

    {found?, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.MixProject.update(igniter, :application, [:extra_applications], fn
      nil -> {:ok, {:code, [:os_mon]}}
      zipper -> Igniter.Code.List.append_new_to_list(zipper, :os_mon)
    end)
  end
end
