defmodule WorkbenchIgniter.EnvFile do
  @moduledoc """
  The project's `.env` and `.env.sample`: what a cartridge needs of the
  environment, written where the project keeps it. Everything that
  works on those two files lives here, as everything on `mix.exs` lives
  in `WorkbenchIgniter.MixFile` and on the compose files in
  `WorkbenchIgniter.ComposeFile`. Igniter has nothing for them.

  The two go together: `.env` is the one the deployments read and git
  ignores, `.env.sample` the one that is committed — so a secret goes
  into the first and its blanked-out line into the second.
  """

  @doc """
  Appends an entry (comment + lines) to the project `.env` and
  `.env.sample`, creating the files when the project has none. A no-op
  when the first variable of `body` is already declared.

  It lets a cartridge own its own variables instead of parking them,
  commented out, in the setup template. Both files receive the very
  same text unless `sample_body` is given — `.env.sample` is meant to
  be committed, so a secret goes in `body` for `.env` and its
  blanked-out line (`KEY=""`) in `sample_body`, the same key first.
  """
  @spec entry(Igniter.t(), String.t(), String.t(), String.t() | nil) :: Igniter.t()
  def entry(igniter, comment, body, sample_body \\ nil) do
    # The first `KEY=` of the body marks the entry as already present.
    marker = body |> String.split("=", parts: 2) |> hd() |> String.trim()

    [{".env", body}, {".env.sample", sample_body || body}]
    |> Enum.reduce(igniter, fn {path, body}, igniter ->
      entry = "# #{comment}\n" <> String.trim_trailing(body, "\n") <> "\n"
      WorkbenchIgniter.TextFile.append_once(igniter, path, entry, marker)
    end)
  end
end
