defmodule Console.Catalog do
  @moduledoc """
  The catalog, read in this BEAM: the workbench's package is a
  dependency of the console, and the shelf is its cartridges'
  manifests — nothing about a project. What `mix workbench.catalog
  --json` prints, as the same string-keyed maps, so the pages read it
  the way they read the JSON.
  """

  alias Mix.Tasks.Workbench.Catalog, as: CatalogTask

  def read do
    Console.Workbench.covers_dir()
    |> CatalogTask.read()
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
