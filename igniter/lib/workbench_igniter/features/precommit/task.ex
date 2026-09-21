defmodule Mix.Tasks.Workbench.Install.Precommit do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Precommit

  @shortdoc "Runs the project's checks before the commit exists"

  @moduledoc """
  #{@shortdoc}

  A pre-commit hook is the cheapest place to find what CI would find
  twenty minutes later: the file nobody formatted, the warning that
  compiles anyway, the lock file with a dependency nobody uses. This
  cartridge installs one that works in a project whose Elixir lives in
  a container.

  Three things land in the project:

  * `#{Precommit.hook()}` — the checks, in order, one block per
    cartridge. It is a plain shell script the project owns: read it,
    move a block, add a line of your own, or run the lot without
    committing with `sh #{Precommit.hook()}`.
  * `.githooks/mix` — how the host reaches `mix`. The hook runs on the
    machine that commits, and that machine has Docker: this is
    `docker compose exec app mix`, warm when the workspace is up and a
    one-off container when it is not.
  * `git_hooks` and its configuration in `config/dev.exs`, which writes
    `.git/hooks/pre-commit` when the dev dependencies compile, backs up
    whatever was there, and removes it again if the configuration goes.

  `--check` chooses among the checks that come with Elixir and belong
  to no cartridge. A cartridge with a check of its own brings it with
  its own option — `credo --githook`, `coveralls --githook` — and owns
  its block here, so ejecting it leaves the rest of the hook standing.

  The hook is local to each clone, which is the whole truth about
  hooks: `#{Precommit.hook()}` travels with the repository and the
  installed hook does not, and anyone can pass `--no-verify`. What must
  hold for everybody is CI's job.

  ## Example

      #{Precommit.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Precommit)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Precommit.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Precommit.install(igniter)
end
