defmodule WorkbenchIgniter.Features.Guidelines do
  @moduledoc """
  The team's coding conventions as a page of the project's own
  documentation: a markdown downloaded from `--url` and added to the
  ExDoc site, under *Support*.

  It builds on [exdoc](../exdoc/), which owns the site and the `docs:`
  block of `mix.exs`; this cartridge only appends its page to the two
  lists that block keeps — `extras` and `groups_for_extras[:Support]` —
  the way clustering appends its exports to a release script it does not
  own. The installer refuses while exdoc is not in (`requires/0`).

  It is the one cartridge that reaches the network to install. That is
  the reason it is a cartridge and not an option of exdoc, where the
  download used to live: inserting the documentation site should not
  depend on a URL being up. When the fetch fails, the page is planted as
  a placeholder naming the URL and a warning says so — the site keeps
  building either way.
  """
  use WorkbenchIgniter.Feature

  @page "assets/exdoc/coding.md"
  @title "Coding guidelines"

  @example ~s|mix workbench.install.guidelines --url "https://raw.githubusercontent.com/user/repo/main/GUIDE.md"|

  @impl true
  def task, do: "workbench.install.guidelines"

  # The page is an ExDoc extra: without the site there is nothing to
  # add it to, and no mix.exs `docs:` block to append to.
  @impl true
  def requires, do: ["exdoc"]

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [url: "URL of the markdown to download as the project's coding guidelines page."]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [url: :string],
      defaults: []
    }
  end

  # The mark: the page itself.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @page)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    url = igniter.args.options[:url]

    if is_nil(url) do
      Igniter.add_issue(igniter, "--url is required: it is the page this cartridge installs.")
    else
      case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
        {[], igniter} -> insert(igniter, url)
        {missing, igniter} -> refuse(igniter, missing)
      end
    end
  end

  defp refuse(igniter, missing) do
    Igniter.add_issue(
      igniter,
      "#{name()} builds on #{Enum.join(missing, " and ")}, not in the project yet. " <>
        "Insert that first: ./wb.sh add #{hd(missing)}"
    )
  end

  defp insert(igniter, url) do
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@page} already exists: the guidelines are in, skipping.")

      {false, igniter} ->
        igniter |> download(url) |> list_in_docs()
    end
  end

  defp download(igniter, url) do
    # Mix tasks don't start dependency applications, and Req needs its
    # Finch pool running before it can make requests.
    {:ok, _} = Application.ensure_all_started(:req)

    try do
      Igniter.create_new_file(igniter, @page, Req.get!(url).body, on_exists: :overwrite)
    rescue
      error ->
        # The page is listed in the mix.exs docs extras: a placeholder
        # keeps `mix docs` working when the download fails.
        igniter
        |> Igniter.create_new_file(
          @page,
          "# #{@title}\n\n> Download failed on insert; fetch the page from " <>
            "<#{url}> and replace this file.\n",
          on_exists: :skip
        )
        |> Igniter.add_warning(
          "Could not download the coding guidelines from #{url} " <>
            "(#{Exception.message(error)}); a placeholder page was created."
        )
    end
  end

  # The two lists exdoc's `docs:` block keeps: the extras themselves and
  # the group they are shown under. Appended, never rewritten — exdoc's
  # own pages stay where its installer put them.
  defp list_in_docs(igniter) do
    igniter
    |> update_docs([:extras], fn zipper ->
      # Real AST, not the `{:code, source}` marker `MixProject.update/4`
      # takes for a whole value: this appends *into* a list.
      Igniter.Code.List.append_new_to_list(
        zipper,
        Sourceror.parse_string!(~s|{"#{@page}", [title: "#{@title}"]}|)
      )
    end)
    |> update_docs([:groups_for_extras, :Support], fn zipper ->
      Igniter.Code.List.append_new_to_list(zipper, Sourceror.parse_string!(~s|"#{@page}"|))
    end)
  end

  defp update_docs(igniter, path, fun) do
    Igniter.Project.MixProject.update(igniter, :project, [:docs | path], fn
      nil -> :error
      zipper -> fun.(zipper)
    end)
  end
end
