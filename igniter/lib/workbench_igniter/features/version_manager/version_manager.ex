defmodule WorkbenchIgniter.Features.VersionManager do
  @moduledoc """
  The project's Erlang and Elixir, in the file a version manager reads.
  A version manager keeps several versions installed side by side on
  the host and picks one per directory, off that file: `cd` into the
  project and `mix`, `iex` and the editor run its versions, `cd` into
  the next and they run the next one's. `.tool-versions` for asdf,
  which mise reads too; `mise.toml` for whoever is on mise and wants
  its own file (`--manager mise`).

  The versions are not an option and not read off `mix.exs` (whose
  `elixir:` requirement is a range, `~> 1.17`, not a version). The
  installer runs inside the toolchain container, so it reports the
  versions that are actually running it — `System.version/0` and the
  OTP release — which is the same stack the image was built from and the
  only source that cannot drift. Whoever wants another pin edits the
  file, which is the project's.

  Elixir is pinned with the OTP it runs on (`1.19.6-otp-28`): both
  managers install Elixir precompiled, and a bare `1.19.6` is the build
  against the *oldest* OTP that Elixir supports, not the one beside it
  in the file (DESIGN.md).

  Everything inside the container ignores both files.
  """
  use WorkbenchIgniter.Feature

  # The manager's name and the file it is told in: the first of each is
  # the one written. mise reads its file as a dotfile too, and a project
  # that has one has told its manager already. The order is the mark's
  # and the state's: asdf's file first.
  @files [{"asdf", ".tool-versions"}, {"mise", "mise.toml"}, {"mise", ".mise.toml"}]
  @managers @files |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

  @impl true
  def task, do: "workbench.install.version_manager"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      manager:
        "The version manager the file is written for: `asdf` (`.tool-versions`, which mise reads too) or `mise` (`mise.toml`). Default: `asdf`."
    ]
  end

  @impl true
  def choices do
    [
      manager: [
        {"asdf", "`.tool-versions`: asdf's file, and mise reads it too"},
        {"mise", "`mise.toml`: the file mise recommends over asdf's"}
      ]
    ]
  end

  @impl true
  def afterwards,
    do:
      "On your machine, in the project: `asdf install` (its erlang and elixir plugins added first) or `mise install`."

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --manager asdf",
      schema: [manager: :string],
      defaults: [manager: "asdf"]
    }
  end

  # The mark: a version file of either manager.
  @impl true
  def installed?(igniter) do
    {Enum.any?(@files, fn {_manager, path} -> Igniter.exists?(igniter, path) end), igniter}
  end

  @doc """
  What the project carries: the manager its version file is for, said
  by which file is there. The versions are no option, so they are no
  state: the file says them.
  """
  @impl true
  def state(igniter) do
    case Enum.find(@files, fn {_manager, path} -> Igniter.exists?(igniter, path) end) do
      nil -> {%{}, igniter}
      {manager, _path} -> {%{manager: manager}, igniter}
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    manager = igniter.args.options[:manager] || "asdf"

    # The mark guards the whole insert: a project that already pins its
    # versions keeps them, whatever this run was asked for.
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "A version file already exists: the pin is in, skipping.")

      {false, igniter} when manager in @managers ->
        {^manager, path} = List.keyfind(@files, manager, 0)
        Igniter.create_new_file(igniter, path, version_file(manager))

      {false, igniter} ->
        Igniter.add_issue(
          igniter,
          "--manager must be one of #{Enum.join(@managers, ", ")}, got: #{manager}"
        )
    end
  end

  @doc """
  The file's content for a manager. Erlang goes first: Elixir runs on
  it.
  """
  @spec version_file(String.t()) :: String.t()
  def version_file("asdf") do
    """
    erlang #{erlang_version()}
    elixir #{elixir_version()}
    """
  end

  def version_file("mise") do
    """
    [tools]
    erlang = "#{erlang_version()}"
    elixir = "#{elixir_version()}"
    """
  end

  # `System.version/0` with the OTP release it runs on, as both managers
  # name the precompiled build: `1.19.6-otp-28`.
  defp elixir_version, do: "#{System.version()}-otp-#{:erlang.system_info(:otp_release)}"

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
