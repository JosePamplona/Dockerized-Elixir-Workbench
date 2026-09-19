# version_manager — Design

*Revision: cartridge v0.1.0 (2026-09-18). Sources consulted on that
date; quotations are verbatim from the page as read then.*

## Abstract

A workspace's stack lives in its image, and nothing on the developer's
own machine knows it. This cartridge writes the Erlang and Elixir the
workspace runs into the file the host's version manager reads:
`.tool-versions` by default, which asdf defines and mise reads, or
`mise.toml` on request. The versions are read off the VM running the
installer, and Elixir is written with the OTP it runs on
(`1.19.6-otp-28`), because both managers install Elixir precompiled and
the bare version names a build for a different OTP. The pin was half of
the `toolchain` cartridge until 2026-09-18; the other half, the
language server's ignore, stayed there. The files it writes were read
back by a real mise; with asdf, the version names were checked against
its listings.

## 1. Problem

A developer's machine holds more than one project, and they do not
agree on an Elixir. A version manager answers that: several versions
installed side by side, one picked per directory off a file in it, so
changing project is a `cd` and not a reinstall. The same file tells a
reader of the repository which versions the project is on, and, being
committed, records when they changed. That is what this cartridge is
for; the rest of this section is how it came to be a box of its own.

The retired `workbench.setup` rendered a `.tool-versions` from
`config.conf`'s stack variables into every project. `toolchain` v0.1.0
rescued it together with the `/.elixir_ls/` ignore, as "what the project
tells the host's toolchain". On 2026-09-18 the author went through the
shelf box by box (`SCRIPT.md`, "The author's selection") and found two
capsules of knowledge in it: `/.elixir_ls/` is ElixirLS's build
directory "and has nothing to do with a version manager". A project may
want either without the other: a developer on Lexical has no
`.elixir_ls/`; a developer who runs everything through `./wb.sh` has no
version manager.

Splitting them raised what the merged box never had to answer: *which*
version manager, and what exactly each one needs to be told.

## 2. Background

### 2.1 asdf and its file

`.tool-versions` is asdf's: one line per tool, the name and a version
[1]. "Whenever `.tool-versions` file is present in a directory, the
tool versions it declares will be used in that directory and any
subdirectories." A tool with no version there fails to run: "Without a
version listed for a tool execution of the tool will **error**." [2]
asdf manages nothing without a plugin per tool — "asdf is only useful
once you install a **plugin**, install a **tool** and manage its
**versions**" [2] — so Erlang and Elixir each need theirs on the host
(asdf-erlang, asdf-elixir).

### 2.2 mise and its two files

mise reads asdf's file and says which it prefers [3]:

> "The `.tool-versions` file is asdf's config file, and mise can use it
> just like `mise.toml`. It isn't as flexible, so `mise.toml` is
> recommended instead."

`mise.toml` carries tools under `[tools]`, and the same page says the
file may be a dotfile: "Paths that start with `mise` can be dotfiles,
e.g. `.mise.toml` or `.mise/config.toml`." Erlang and Elixir are built
into mise, no plugin to add: "These instructions use mise's built-in
elixir support." [4], and the same for Erlang [5]. Its Elixir page
asks for the pair: "Erlang/OTP is required by Elixir." — "Declare both
Erlang and Elixir for the project." [4]

### 2.3 What a bare Elixir version installs

Both managers install Elixir from the precompiled builds of
`builds.hex.pm` — mise's plugin lists
`https://builds.hex.pm/builds/elixir/builds.txt` and downloads
`https://builds.hex.pm/builds/elixir/{version}.zip` [6]. asdf-elixir's
README says what the version's name decides [7]:

> "The precompiled packages are built against every officially
> supported OTP version, however if you only specify the elixir version,
> like `1.4.5`, the downloaded binaries will be those compiled against
> the oldest OTP release supported by that version."

> "If you would like to use precompiled binaries built with a more
> recent OTP, you can append `-otp-${OTP_MAJOR_VERSION}` to any
> installable version."

And Erlang is not brought along [7]: "You do not need to have Erlang
installed to install a precompiled version of Elixir installed, but you
will need to have it available at runtime, otherwise your Elixir
commands will fail."

## 3. Design

### 3.1 One box, the manager as its option

asdf and mise answer one need with one kind of file; what differs is
the file's name and syntax. Two boxes would be two claims on the shelf
for one decision, and a reader on neither manager would have to work
out that they exclude each other. So: `version_manager`, named for the
role — as `db admin` and `dashboard enhancements` will be — with
`--manager asdf|mise` as a closed choice (`choices/0`). A third manager
that reads `.tool-versions` needs nothing; one with a file of its own
is one more value.

### 3.2 Elixir is pinned with its OTP

`toolchain` wrote `elixir 1.19.6`. By 2.3 that is the build for the
oldest OTP Elixir 1.19 supports (26), on a host whose Erlang, by the
line above it, is 28. Whether or not it runs, it is not the Elixir the
image runs, which is the one thing the file exists to say. The
installer knows the OTP it runs on
(`:erlang.system_info(:otp_release)`), so it writes `1.19.6-otp-28`.
This repository's own `.tool-versions` was already written that way by
hand.

**The versions are not options.** `toolchain` had `--elixir` and
`--erlang`, with its own README's "rarely what you want" beside them.
No case held: an option to type the versions contradicts the one claim
the file makes, that it agrees with what runs the project; it would
only act on the first insert, since the mark guards the file after; and
what it could serve — a `ref:` or a `path:` [1], a patch the host's
manager does not list — is an edit of a two-line file that is the
project's own from the insert on. In the console's form they were two
empty fields inviting a pin typed from memory.

### 3.3 The option changes the file, and the file is the state

`--manager asdf` writes `.tool-versions`; `--manager mise` writes
`mise.toml`. The alternative — always `.tool-versions`, the option only
changing the sentence that follows the insert — beat nothing: the
option would leave no mark, and `state/1` must read every option off
"a mark the project has for its own sake" (`Feature.state/1`). Here the
file that is there *is* the manager, with no record kept for the
workbench.

The default is asdf because its file is the one both read (2.2): a
project that does not know its developers' manager serves them all with
it. `mise` is for the team that is on mise and wants the file mise
recommends, where its tasks and env can later live.

### 3.4 The mark is any version file

`.tool-versions`, `mise.toml` or `.mise.toml`: with any of them the
insert is a no-op with a notice. Never overwritten, as before; and a
project already on mise is not handed an asdf file beside its own,
which mise would read along with it and a reader would have to
reconcile. The cost: a `mise.toml` that holds only tasks counts as a
pin. Rare in a project the workbench just generated, and the notice
says why nothing was written.

`state/1` answers for the one option: the manager, off the first file
found in that order — asdf's first, since when both are there asdf
reads only its own. The versions are no option, so they are no state
(`Feature.state/1`: the answer has the schema's keys); the file says
them.

### 3.5 What is deliberately absent

* **No install.** The cartridge runs in the container; the manager is
  on the host. `afterwards/0` carries the sentence: `asdf install`
  (plugins added first) or `mise install`.
* **No `.gitignore`, no editor settings.** Those are the language
  server's box.
* **No Node.** The workbench's images carry node, but a stock Phoenix
  project needs none on the host (esbuild and tailwind are standalone
  binaries).
* **No re-pin.** When `config.conf` moves the stack the file stays as
  written. `rerun` is `:noop`; changing the pin is editing two lines.
  See 5.

## 4. Evaluation

* The cartridge's suite: both files, the refusal of an unknown
  manager, the three marks, `state/1` on both files and on ones written
  by hand.
* **mise**, for real: `jdxcode/mise` 2026.9.11 in a container, given
  the `mise.toml` this cartridge writes and then the same pins as
  `.tool-versions`. `mise ls --current` read `elixir 1.19.6-otp-28` and
  `erlang 28.5.0.6` from each file, and `mise ls-remote` lists both
  versions by those names.
* **asdf**: v0.14.0 on the author's machine lists `1.19.6-otp-28`
  (`asdf list all elixir`) and `28.5.0.6` (`asdf list all erlang`).

Not verified: an actual `asdf install` / `mise install` of the pair
(Erlang builds from source under asdf; minutes, and the host's
business), and asdf 0.16+, the Go rewrite, whose file format is the
same by its documentation [1].

## 5. Limitations and open questions

* **Drift after a stack change.** The file agrees with the image on the
  day of the insert, and nothing says so or repairs it when they part.
  A `--repin` would be the first option here that rewrites a file the
  project owns; the workbench's status saying the disagreement would
  ask nothing of the project, and is the likelier road.
* **Erlang's patch version.** The installer writes the full
  `OTP_VERSION` (`28.5.0.6`). Both managers list it today; a manager
  that only knew `28.5` would not find it. Editing the line is the way
  out.
* **mise on musl or macOS** falls back to building Erlang with kerl
  [5]; nothing here changes with it.

## 6. Relation to `toolchain`

`toolchain` v0.2.0 is what is left: `/.elixir_ls/` in `.gitignore`. Its
name and scope — ElixirLS is a language server, not only VS Code's, and
Lexical, Next LS and Expert keep directories of their own — are its own
paper's to settle.

## References

1. asdf, *Configuration* — `.tool-versions`, version formats.
   <https://asdf-vm.com/manage/configuration.html>
2. asdf, *Getting Started* — plugins, version resolution.
   <https://asdf-vm.com/guide/getting-started.html>
3. mise, *Configuration* — `mise.toml`, `[tools]`, `.tool-versions`.
   <https://mise.jdx.dev/configuration.html>
4. mise, *Elixir*. <https://mise.jdx.dev/lang/elixir.html>
5. mise, *Erlang* — precompiled builds, the kerl fallback.
   <https://mise.jdx.dev/lang/erlang.html>
6. mise, `src/plugins/core/elixir.rs` — the version list and the
   download URL.
   <https://github.com/jdx/mise/blob/main/src/plugins/core/elixir.rs>
7. asdf-elixir, *README* — precompiled builds and `-otp-NN`.
   <https://github.com/asdf-vm/asdf-elixir>
