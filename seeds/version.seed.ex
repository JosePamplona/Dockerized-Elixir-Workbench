defmodule Mix.Tasks.Version do
  use Mix.Task

  @readme_file "%{readme_file}"
  @mix_file    "%{mix_file}"
  
  @moduledoc """
    Adjusts version on `#{@mix_file}` file and the version badge on 
    `#{@readme_file}` file.
    """

  @shortdoc "Sets a new version for the project"
  @doc false
  def run([new_version]) do
    Mix.shell().info("Setting new version...")

    readme_content = File.read!(@readme_file)
    mix_content = File.read!(@mix_file)

    with \
      :ok <- format_readme_file(readme_content, new_version),
      :ok <- format_mix_file(mix_content, new_version)
    do
      Mix.shell().info(
        "Success! project new version: #{new_version}\n" <>
        "  #{@mix_file}\n" <>
        "  #{@readme_file}"
      )
    else
      {:error, file} -> Mix.raise("Failure: Incompatible #{file} file.")
    end
  end

  # == Private =================================================================

  defp format_readme_file(content, version) do
    ~r/!\[v(.*)\]\(https:\/\/.*?\/version-(.*)-white.svg/
    |> Regex.scan(content)
    |> case do
      [[line, match_1, match_2]] when match_1 == match_2 ->
        File.write!(
          @readme_file,
          String.replace(content, line, String.replace(line, match_1, version))
        )

      _ -> {:error, @readme_file}
    end
  end
  
  defp format_mix_file(content, version) do
    ~r/.*?version: "(.*)"/
    |> Regex.scan(content)
    |> case do
      [[line, match]] ->
        File.write!(
          @mix_file,
          String.replace(content, line, String.replace(line, match, version))
        )

      _ -> {:error, @mix_file}
    end
  end
end
