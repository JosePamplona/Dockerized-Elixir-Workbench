defmodule WorkbenchIgniter.Deployments do
  @moduledoc """
  The workspace's three compose files as they stand beside the project,
  and whether each still says what the cartridges ask for.

  A file is baked when it is there. It is in sync when the services it
  declares are the ones `WorkbenchIgniter.Compose.service_names/2`
  renders for what the project asks today — nothing stray (a service
  left behind by a cartridge that was ejected), nothing missing (one a
  cartridge brought in since). `wb.sh compose_behind` asks the same
  question of the dev file by baking it again and comparing bytes; this
  asks it of all three by name, which is the question the Record paper
  puts: does the file say what the cartridges ask for.
  """

  alias WorkbenchIgniter.Compose

  @files [
    dev: "docker-compose.yml",
    prod: "docker-compose.prod.yml",
    scaled: "docker-compose.scaled.yml"
  ]

  @typedoc "One deployment's file: baked, its services, and its sync with the project."
  @type t :: %{
          baked: boolean(),
          services: [String.t()],
          in_sync: boolean() | nil,
          stray: [String.t()],
          missing: [String.t()]
        }

  @doc "The three files under `dir`, against `services` — what the cartridges ask for."
  @spec read(Path.t(), [String.t()]) :: %{dev: t(), prod: t(), scaled: t()}
  def read(dir, services) do
    Map.new(@files, fn {deploy, file} ->
      {deploy, one(deploy, Path.join(dir, file), services)}
    end)
  end

  defp one(deploy, path, services) do
    case File.read(path) do
      {:ok, text} ->
        declared = declared(text)

        %{names: names, optional: optional, replicas: replicas} =
          Compose.service_names(deploy, services)

        replica? = &Regex.match?(~r/^app\d+$/, &1)

        stray =
          for s <- declared,
              s not in names,
              s not in optional,
              not (replicas and replica?.(s)),
              do: s

        missing =
          for(n <- names, n not in declared, do: n) ++
            if(replicas and not Enum.any?(declared, replica?), do: ["app1"], else: [])

        %{
          baked: true,
          services: declared,
          in_sync: stray == [] and missing == [],
          stray: stray,
          missing: missing
        }

      _ ->
        %{baked: false, services: [], in_sync: nil, stray: [], missing: []}
    end
  end

  @doc "The service names a compose file declares (`WorkbenchIgniter.ComposeFile.services/1`)."
  @spec declared(String.t()) :: [String.t()]
  defdelegate declared(text), to: WorkbenchIgniter.ComposeFile, as: :services
end
