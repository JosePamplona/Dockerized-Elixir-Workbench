<!-- Draft for an issue on https://github.com/mishka-group/mishka_chelekom
     Not published yet. When it is, put its URL in:
       - igniter/lib/workbench_igniter/features/ash/ash.ex  (mishka_first/1)
       - igniter/lib/workbench_igniter/features/ash/DESIGN.md  §2.5
       - igniter/lib/workbench_igniter/features/ash/CHANGELOG.md  v0.9.0
       - CHANGELOG.md  (Unreleased)
     and delete this file. -->

# The installer overwrites `app.css` with the version on disk, losing what other installers wrote in the same run

**Package:** `mishka_chelekom` 0.0.9
**With:** `igniter` 0.8.4, Phoenix 1.8.15 (Tailwind 4, `@import "tailwindcss" source(none);`)

## Summary

`MishkaChelekom.Generators.Assets.import_and_setup_theme/2` reads
`assets/css/app.css` with `File.read/1` — from the file system — and then writes
that content back whole through the igniter. Igniter does not flush its sources
to disk until the end of a run, so during an `mix igniter.install a b c …` run
that read returns the file **as it was before the run started**. Every change any
installer made to `app.css` earlier in the same run is silently discarded.

The installer's own JavaScript path a few lines above does it correctly, reading
from the source rather than the disk, which is why `app.js` is not affected.

## Reproduction

```bash
mix igniter.install ash_authentication_phoenix mishka_chelekom
```

(any installer that patches `app.css` before `mishka_chelekom`, in one run)

`ash_authentication_phoenix.install` adds

```css
@source "../../deps/ash_authentication_phoenix";
```

right after the `@import "tailwindcss"` line, so that Tailwind scans the
dependency for the classes its sign-in pages use. After the run, that line is not
in `app.css`. Mishka's own `@import "../vendor/mishka_chelekom.css";` and its
`@theme` block are there.

Observed on a real project (Phoenix 1.8.15, Tailwind 4, 22 installers in one
`igniter.install`): of the 70 classes on the rendered `/sign-in` page, **18 had no
rule** in the compiled stylesheet — `bg-blue-500`, `hover:bg-blue-600`,
`focus:ring-blue-400`, `placeholder-gray-400`, the `dark:` variants — so the page
rendered unstyled. Adding the lost `@source` line by hand brings it to 70 of 70.

Two details that pin the cause:

* `ash_authentication_phoenix.install` reported `✔` and printed **no** notice. Its
  installer only emits its "configure Tailwind by hand" notice when it cannot
  patch the file, and notices did print in that run (Cinder's "Cinder Tailwind
  setup complete" is in the same `Notices:` block). So it did patch the source —
  the write was discarded afterwards.
* `cinder.install`, which patches the same anchor in the same file, runs *after*
  `mishka_chelekom` and its two `@import` lines survive. It reads the source with
  `Rewrite.source!(igniter.rewrite, "assets/css/app.css")`, not the disk.

## Cause

`lib/mishka_chelekom/generators/assets.ex:167`

```elixir
defp import_and_setup_theme(igniter, app_css_path) do
  theme_path = Core.lib_priv("assets/css/theme.css")

  with {:ok, css_content} <- File.read(app_css_path),          # <-- the disk
       {:ok, theme_content} <- SimpleCSSUtilities.read_theme_content(theme_path),
       {:ok, updated_content} <-
         SimpleCSSUtilities.add_import_and_theme(
           css_content,
           "../vendor/mishka_chelekom.css",
           theme_content
         ) do
    igniter
    |> Igniter.create_or_update_file(app_css_path, updated_content, fn source ->
      Rewrite.Source.update(source, :content, updated_content)  # <-- ignores `source`
    end)
```

The updater function receives the live `source` and ignores it, writing the
content computed from the disk read instead.

## Suggested fix

The principle: a project file has to be read **through the igniter**, not with
`File.read/1`. During a run, the igniter's copy is the only one that has the
changes made so far; the disk still holds the pre-run file.

The module already does this correctly for JavaScript — `update_js_files/2`
(`assets.ex:110`) takes the existing content from the source it is handed:

```elixir
with original_content <- Rewrite.Source.get(source, :content),
```

`import_and_setup_theme/2` only needs to move the computation inside the updater
and take its input from there, keeping the "no app.css" message:

```elixir
defp import_and_setup_theme(igniter, app_css_path) do
  theme_path = Core.lib_priv("assets/css/theme.css")

  with true <- Igniter.exists?(igniter, app_css_path),
       {:ok, theme_content} <- SimpleCSSUtilities.read_theme_content(theme_path) do
    Igniter.update_file(igniter, app_css_path, fn source ->
      with css_content <- Rewrite.Source.get(source, :content),
           {:ok, updated_content} <-
             SimpleCSSUtilities.add_import_and_theme(
               css_content,
               "../vendor/mishka_chelekom.css",
               theme_content
             ) do
        Rewrite.Source.update(source, :content, updated_content)
      else
        {:error, reason} -> {:error, "Error processing CSS file: #{inspect(reason)}"}
      end
    end)
  else
    false ->
      Igniter.add_issue(igniter, """
      The app.css file does not exist at #{app_css_path}.
      Please ensure your Phoenix application has been properly set up with assets.
      """)

    {:error, reason} ->
      Igniter.add_issue(igniter, "Error processing CSS file: #{inspect(reason)}")
  end
end
```

`Igniter.update_file/3` includes the file and hands the updater the live source,
and it understands an `{:error, message}` return (`igniter.ex:618`), so the two
failure paths stay apart: a missing `app.css` is still the explicit message,
and a CSS parse failure becomes an issue on the source.

The other shape, if you prefer to compute outside the updater, is what
`cinder.install` does on the same file (`cinder.install.ex:131`):

```elixir
igniter = Igniter.include_glob(igniter, app_css_path)
source = Rewrite.source!(igniter.rewrite, app_css_path)
content = Rewrite.Source.get(source, :content)
```

Either reads the same thing — `Rewrite.Source.get(source, :content)` is the
source's current content. What matters is that neither is `File.read/1`.

`setup_headless_css/2` reads its own `priv` file with `File.read!`, which is
fine: that is not a project file. Only project files need to come from the
igniter.

## Workaround

Order `mishka_chelekom` first in the `igniter.install` list, so there is nothing
in `app.css` yet for it to discard and every later installer stacks on top of its
write. Its own output is unchanged either way, since the disk read returns the
same pre-run file.
