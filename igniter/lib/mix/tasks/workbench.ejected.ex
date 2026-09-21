defmodule Mix.Tasks.Workbench.Ejected do
  use Mix.Task

  @shortdoc "Takes away what an ejected cartridge left outside the tree"

  @moduledoc """
  #{@shortdoc}

      mix workbench.ejected NAME

  The half of an eject a revert cannot do. `wb.sh eject` reverts the
  commit that inserted NAME, which takes away everything the insert
  wrote in the tree; what the insert left outside it — precommit's hook
  in `.git/hooks` — is NAME's own `ejected/1` to take away, and this
  runs it, on the project in the working directory. It runs after the
  revert is committed, so the cartridge is no longer in the project and
  only its module, here, knows what it left.

  One `ejected> ` line per thing undone, for `wb.sh` to find in what
  mix prints on its way to the task; nothing when there was nothing.
  """

  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(argv) do
    name =
      case argv do
        [name | _] -> name
        [] -> Mix.raise("Missing cartridge name. Try: mix workbench.ejected precommit")
      end

    feature =
      Features.named(name) ||
        Mix.raise("No cartridge named #{name}. The catalog: mix workbench.catalog")

    File.cwd!()
    |> feature.ejected()
    |> Enum.each(&IO.puts("ejected> " <> &1))
  end
end
