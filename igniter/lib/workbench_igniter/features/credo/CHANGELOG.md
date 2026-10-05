<!-- markdownlint-disable MD024 -->
# Changelog: credo

The cartridge's own versions, over what it installs in a project —
independent of the workbench release that ships it.

## v0.2.0 - (2026-09-21)

### Changed

- **`--githook` builds on precommit, and no longer inserts it.** The
  option refuses while the precommit cartridge is not in, naming
  `./wb.sh add precommit`, and writes nothing. Inserted along,
  precommit came in credo's own commit: it had no insert of its own to
  eject, and credo's eject took its files and left its hook in
  `.git/hooks`, calling a runner that was gone. The console shows the
  switch unlit while precommit is not in, and precommit's eject waits
  until credo's block is gone.

## v0.1.0 - (2026-09-20)

The first version of the cartridge's own record: it was written before
a cartridge had one, and gets it on this change.

### Added

- **`--githook`**: `mix credo` before every commit. The hook, the way
  it reaches `mix` inside the container and the checks that come with
  Elixir belong to the **precommit** cartridge, which this one composes
  when asked; what Credo adds is a block of `.githooks/pre-commit`
  belonging to this cartridge alone
  (`WorkbenchIgniter.BlockFile`), so ejecting either box leaves the
  other's checks standing. The line is `mix credo`, not `mix credo
  --strict`: a hook that refuses the first commit after it is inserted
  is one the developer turns off. The block is born **above the hook's
  divider** (`stage: :fast`): Credo reads the source and does not
  compile the project, so it stands with the checks that refuse a
  commit in a second, ahead of anything that compiles it.
- `state/1`, which the cartridge had no need of while it had no
  options: whether Credo's block stands in the project's hook.
- `DESIGN.md` and this file, the papers the anatomy asks of a cartridge
  on its next change.
