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

  @page "guides/coding.md"
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

  # --url leaves no mark the project keeps: the page is the download,
  # and only a failed one names its URL in the placeholder — which is
  # not the option, so it is not read either.
  @impl true
  def state(igniter), do: {%{url: nil}, igniter}

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    url = igniter.args.options[:url]

    if is_nil(url) do
      Igniter.add_issue(igniter, "--url is required: it is the page this cartridge installs.")
    else
      case WorkbenchIgniter.Feature.missing_requirements(igniter, __MODULE__) do
        {[], igniter} -> insert(igniter, url)
        {missing, igniter} -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, missing)
      end
    end
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
  # the group they are shown under — exdoc's to write into.
  defp list_in_docs(igniter),
    do: WorkbenchIgniter.Features.Exdoc.list_page(igniter, @page, @title, :Support)
end
