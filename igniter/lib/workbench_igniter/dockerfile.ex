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
