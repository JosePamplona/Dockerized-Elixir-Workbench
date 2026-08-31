defmodule WorkbenchIgniter.Features.Toolchain do
  @moduledoc """
  What the project tells the *host's* toolchain — not the workbench's
  image: a `.tool-versions` naming the Elixir and Erlang it runs on, and
  the language server's cache kept out of git.

  The versions are not asked for and not read off `mix.exs` (whose
  `elixir:` requirement is a range, `~> 1.17`, not a version). The
  installer runs inside the toolchain container, so it reports the
  versions that are actually running it — `System.version/0` and the
  OTP release — which is the same stack the image was built from and the
  only source that cannot drift.

  `.tool-versions` is read by asdf and by mise; other version managers
  ignore it, and so does everything inside the container.
  """
  use WorkbenchIgniter.Feature

  @gitignore_comment "Elixir Language Server directory."
  @gitignore_entry "/.elixir_ls/"

  @impl true
  def task, do: "workbench.install.toolchain"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      elixir: "Elixir version. Default: the one running the installer.",
      erlang: "Erlang/OTP version. Default: the one running the installer."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task(),
      schema: [elixir: :string, erlang: :string],
      defaults: []
    }
  end

  # The mark: the file it creates.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, ".tool-versions")

  @doc """
  What the project carries of the versions, read off its
  `.tool-versions` — so a form shows what is pinned there now.
  """
  @impl true
  def state(igniter) do
    if Igniter.exists?(igniter, ".tool-versions") do
      igniter = Igniter.include_existing_file(igniter, ".tool-versions")
      content = igniter.rewrite |> Rewrite.source!(".tool-versions") |> Rewrite.Source.get(:content)

      state =
        for [_, tool, version] <- Regex.scan(~r/^(elixir|erlang)\s+(\S+)/m, content),
            into: %{},
            do: {String.to_atom(tool), version}

      {state, igniter}
    else
      {%{}, igniter}
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options

    # The mark guards the whole insert: a project that already pins its
    # versions keeps them, whatever this run was asked for.
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, ".tool-versions already exists: the pin is in, skipping.")

      {false, igniter} ->
        igniter
        |> Igniter.create_new_file(".tool-versions", tool_versions(opts))
        |> WorkbenchIgniter.gitignore_entry(@gitignore_comment, @gitignore_entry)
    end
  end

  @doc """
  The file's two lines. The Elixir version is `System.version/0` without
  its OTP suffix, the Erlang one the release of the VM running this.
  """
  @spec tool_versions(keyword()) :: String.t()
  def tool_versions(opts \\ []) do
    """
    erlang #{opts[:erlang] || erlang_version()}
    elixir #{opts[:elixir] || System.version()}
    """
  end

  defp erlang_version do
    # The major release plus the full version from the release file, as
    # asdf names them (`27.3.4.2`); the file is absent on some builds,
    # where the major alone is what there is to say.
    major = List.to_string(:erlang.system_info(:otp_release))
    path = Path.join([:code.root_dir(), "releases", major, "OTP_VERSION"])

    case File.read(path) do
      {:ok, version} -> String.trim(version)
      _ -> major
    end
  end
end
