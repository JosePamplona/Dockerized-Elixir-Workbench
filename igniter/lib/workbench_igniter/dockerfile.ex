defmodule WorkbenchIgniter.Dockerfile do
  @moduledoc """
  The project's production `Dockerfile`, the one `mix phx.gen.release
  --docker` writes at birth. Everything that reads it lives here.
  Igniter has nothing for it.

  The workbench keeps no template of that file: it is Phoenix's, from
  Phoenix's own, and a base cartridge that changes what it should say —
  the first bundler, which brings `assets/` — has it generated again,
  before and after, and merges the difference
  (`WorkbenchIgniter.PhxDelta.release/3`). To generate it again the
  generator needs the stack it was made with, which it asks hex's build
  server for at birth; here the file itself is asked (`stack/1`).
  """

  @doc """
  The stack a `Dockerfile` from `phx.gen.release --docker` names in its
  `ARG` lines — Elixir, OTP, the Debian image (`trixie-20260824-slim`)
  — so the same Dockerfile can be generated again; `nil` for no
  Dockerfile or one written by someone else. The generator reaches
  hex's build server for those at birth; here they are what the
  project already has.
  """
  @spec stack(String.t() | nil) :: map() | nil
  def stack(nil), do: nil

  def stack(dockerfile) do
    with [_, elixir] <- Regex.run(~r/^ARG ELIXIR_VERSION=(\S+)/m, dockerfile),
         [_, otp] <- Regex.run(~r/^ARG OTP_VERSION=(\S+)/m, dockerfile),
         [_, debian] <- Regex.run(~r/^ARG DEBIAN_VERSION=(\S+)/m, dockerfile) do
      %{elixir_vsn: elixir, otp_vsn: otp, debian_version: debian}
    else
      _ -> nil
    end
  end

  @apt "--no-install-recommends build-essential git \\\n"
  @setup "RUN mix assets.setup\n"
  @manifests "COPY assets/package*.json assets/\n"

  @doc """
  What the production image owes once `npm install` is hooked into
  `assets.setup`, as ash_typescript's installer does: nodejs and npm in
  the builder stage, and the package manifests copied before `RUN mix
  assets.setup`. Phoenix runs that step before `COPY assets` on
  purpose — in a phx.new project it only downloads the esbuild and
  tailwind binaries, so the layer caches ahead of the code — and its
  builder installs no node; both held until a package hooked in a step
  that needs `assets/package.json`. The manifests alone go in first,
  so the npm layer still caches on them and not on every asset.

  Phoenix's own Dockerfile (`stack/1`) with the assets steps in it is
  patched, once; anything else is left alone with a notice that says
  what it owes. A project without a Dockerfile owes nothing.
  """
  @spec npm(Igniter.t()) :: Igniter.t()
  def npm(igniter) do
    if Igniter.exists?(igniter, "Dockerfile") do
      igniter = Igniter.include_existing_file(igniter, "Dockerfile")
      content = igniter.rewrite |> Rewrite.source!("Dockerfile") |> Rewrite.Source.get(:content)
      npm(igniter, phoenixs_with_assets?(content))
    else
      igniter
    end
  end

  defp npm(igniter, true) do
    Igniter.update_file(
      igniter,
      "Dockerfile",
      &Rewrite.Source.update(&1, :content, fn content -> with_npm(content) end)
    )
  end

  defp npm(igniter, false) do
    Igniter.add_notice(igniter, """
    The Dockerfile is not phx.gen.release's, or carries no assets steps, \
    so it was left alone. ash_typescript's installer hooks `npm install` \
    into `assets.setup`: the production image needs nodejs and npm in its \
    builder stage, and assets/package.json copied in before `RUN mix \
    assets.setup` (Phoenix copies assets/ after it).\
    """)
  end

  defp phoenixs_with_assets?(content),
    do:
      stack(content) != nil and String.contains?(content, @apt) and
        String.contains?(content, @setup)

  defp with_npm(content) do
    content =
      if String.contains?(content, "nodejs"),
        do: content,
        else:
          String.replace(
            content,
            @apt,
            "--no-install-recommends build-essential git nodejs npm \\\n"
          )

    if String.contains?(content, @manifests) do
      content
    else
      String.replace(
        content,
        @setup,
        "# ash_typescript hooks `npm install` into assets.setup: the manifests\n" <>
          "# go in first, so the npm layer caches on them alone.\n" <> @manifests <> @setup
      )
    end
  end

  @doc """
  The stack as Phoenix's `Dockerfile.eex` binds it, for the `template`
  at hand: up to Phoenix 1.8.13 the Debian image was
  `debian`-`debian_vsn`-slim, from 1.8.14 `debian_vsn` is the whole of
  it. Nothing for no stack.
  """
  @spec binding(map() | nil, Path.t()) :: keyword()
  def binding(nil, _template), do: []

  def binding(docker, template) do
    split =
      case Regex.run(~r/^([a-z]+)-(\d+)-slim$/, docker.debian_version) do
        [_, name, date] -> [debian: name, debian_vsn: date]
        nil -> [debian: docker.debian_version, debian_vsn: docker.debian_version]
      end

    whole = [debian_vsn: docker.debian_version]

    [elixir_vsn: docker.elixir_vsn, otp_vsn: docker.otp_vsn] ++
      if(File.read!(template) =~ "<%= debian %>", do: split, else: whole)
  end
end
