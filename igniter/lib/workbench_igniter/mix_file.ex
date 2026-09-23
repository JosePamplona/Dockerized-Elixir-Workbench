defmodule WorkbenchIgniter.MixFile do
  @moduledoc """
  `mix.exs` read as what it is — the project's keywords, its
  dependencies, its aliases — and a capability's change to it applied
  as operations on those, through Igniter, never as a text merge.

  A base cartridge asks phx.new what a capability is by generating the
  project without and with it (`WorkbenchIgniter.PhxDelta`). For most
  files the two are merged three ways onto the project's own text. For
  `mix.exs` that failed on every project as soon as anything sat next
  to where phx.new writes: the workbench's own dependency of birth on
  the `deps:` line, right before html's `compilers:`; a dependency the
  project added where esbuild's go (2026-09-16). Here `diff/2` reads
  base and theirs as code and says what the capability adds or changes
  — a project keyword, a dependency, an alias — and `apply/4` puts each
  in with Igniter's own hands, which find `deps:` in `def project` and
  the list in `defp deps` by the tree, whatever surrounds them.

  What is read: the keyword list `def project` returns, the list
  literal `defp deps` ends in (the shape Igniter itself reads
  dependencies from — and why the workbench's dependency is added on
  the `deps:` line, `deps() ++ workbench_dep()`, never as `] ++ …` on
  the list), and the keyword list `defp aliases` returns. A dependency
  is known by its name, a keyword by its key. A value is the code as
  written — `runtime: Mix.env() == :dev` stays an expression.

  What is not touched: a keyword or alias the project itself changed
  from what phx.new had, when the capability changes it too — that is
  the project's decision, and an issue says so, naming the key; a
  dependency the project already has, in any version, stays as it is.
  """

  alias Sourceror.Zipper

  @typedoc "A key or a name, and the code it maps to."
  @type entry :: {atom(), Macro.t()}

  @doc """
  What `theirs` has over `base`: `project` and `aliases` are the
  keywords theirs adds or changes, `deps` the dependencies theirs adds.
  Read off the code, with `read/1`.
  """
  @spec diff(String.t(), String.t()) :: %{project: [entry], deps: [entry], aliases: [entry]}
  def diff(base, theirs) do
    b = read(base)
    t = read(theirs)

    %{
      project: changed(b.project, t.project),
      aliases: changed(b.aliases, t.aliases),
      deps: Enum.reject(t.deps, fn {name, _} -> List.keymember?(b.deps, name, 0) end)
    }
  end

  defp changed(base, theirs) do
    Enum.reject(theirs, fn {key, code} ->
      case List.keyfind(base, key, 0) do
        {^key, was} -> same?(was, code)
        nil -> false
      end
    end)
  end

  @doc """
  A `mix.exs` as its three lists: `project`, the keywords `def project`
  returns; `deps`, the dependencies of the list `defp deps` ends in,
  each as `{name, code}`; `aliases`, the keywords `defp aliases`
  returns. Empty where the function is not there or does not end in a
  literal.
  """
  @spec read(String.t()) :: %{project: [entry], deps: [entry], aliases: [entry]}
  def read(text) do
    {:ok, ast} = Code.string_to_quoted(text)

    %{
      project: keywords(body_of(ast, :project)),
      deps: deps_of(body_of(ast, :deps)),
      aliases: keywords(body_of(ast, :aliases))
    }
  end

  @doc """
  What `mix.exs` asks for of each package: `%{name => requirement}`,
  and `nil` for a dependency given by path or git, which has no version
  to ask for. Read off the file, never off `Mix.Project.config()`,
  which is the project as it was when Mix pushed it: in a long-running
  process a package inserted since would read as pinned by nobody.
  """
  @spec requirements(String.t()) :: %{atom() => String.t() | nil}
  def requirements(text) do
    %{deps: deps} = read(text)
    Map.new(deps, fn {name, dep} -> {name, requirement_of(dep)} end)
  end

  @typedoc """
  Where a dependency given by git comes from: the repository's `url`,
  `repo` as `owner/name` when it lives on GitHub, and the one of `tag`,
  `branch` or `ref` it is held to.
  """
  @type git :: %{
          url: String.t(),
          repo: String.t() | nil,
          tag: String.t() | nil,
          branch: String.t() | nil,
          ref: String.t() | nil
        }

  @doc """
  Where each dependency of `mix.exs` comes from, when that is git:
  `%{name => git}`, and nothing for a package from hex or a path. A
  dependency from git has no requirement to read; what it is held to
  is its tag, and that is the version a reader asks for.
  """
  @spec sources(String.t()) :: %{atom() => git()}
  def sources(text) do
    %{deps: deps} = read(text)
    for {name, dep} <- deps, git = git_of(dep), into: %{}, do: {name, git}
  end

  @doc "The git source of one dependency, as code (`read/1`); nil when not from git."
  @spec git_of(Macro.t()) :: git() | nil
  def git_of(dep) do
    options = options_of(dep)

    url =
      case options do
        [_ | _] -> Keyword.get(options, :git) || github_url(Keyword.get(options, :github))
        _ -> nil
      end

    if is_binary(url) do
      %{
        url: url,
        repo: repo_of(url),
        tag: string(options[:tag]),
        branch: string(options[:branch]),
        ref: string(options[:ref])
      }
    end
  end

  defp options_of({_name, options}) when is_list(options), do: keywords(options)

  defp options_of({:{}, _, [_name, _requirement, options]}) when is_list(options),
    do: keywords(options)

  defp options_of(_dep), do: []

  defp github_url(repo) when is_binary(repo), do: "https://github.com/#{repo}.git"
  defp github_url(_repo), do: nil

  @doc "`owner/name` of a GitHub repository's url; nil for any other host."
  @spec repo_of(String.t()) :: String.t() | nil
  def repo_of(url) do
    case Regex.run(~r{github\.com[/:]([^/]+/[^/]+?)(?:\.git)?/?$}, url) do
      [_, repo] -> repo
      nil -> nil
    end
  end

  defp string(value) when is_binary(value), do: value
  defp string(_value), do: nil

  @doc "The requirement one dependency asks for, as code (`read/1`); nil for path or git."
  @spec requirement_of(Macro.t()) :: String.t() | nil
  def requirement_of({_name, requirement}) when is_binary(requirement), do: requirement

  def requirement_of({:{}, _, [_name, requirement | _]}) when is_binary(requirement),
    do: requirement

  def requirement_of(_dep), do: nil

  # The last expression of the function's body, or nil.
  defp body_of(ast, name) do
    {_, found} =
      Macro.prewalk(ast, nil, fn
        {kind, _, [{^name, _, args}, [do: body]]} = node, nil
        when kind in [:def, :defp] and args in [nil, []] ->
          {node, last_expression(body)}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp last_expression({:__block__, _, expressions}), do: List.last(expressions)
  defp last_expression(expression), do: expression

  # A keyword list literal's pairs; anything else reads as none.
  defp keywords(list) when is_list(list) do
    if Keyword.keyword?(list), do: list, else: []
  end

  defp keywords(_), do: []

  # A dependency is a tuple whose first element is its name.
  defp deps_of(list) when is_list(list) do
    for dep <- list, name = dep_name(dep), do: {name, dep}
  end

  defp deps_of(_), do: []

  defp dep_name({name, _}) when is_atom(name), do: name
  defp dep_name({:{}, _, [name | _]}) when is_atom(name), do: name
  defp dep_name(_), do: nil

  defp same?(a, b), do: Macro.to_string(a) == Macro.to_string(b)

  @doc """
  The capability's change to the project's `mix.exs`, as `diff/2`
  says it, applied with Igniter: each project keyword and alias set
  where `def project` and `defp aliases` keep it — created when it is
  not there — unless the project changed it from base's own, which is
  reported as an issue; each dependency appended to the list `defp
  deps` ends in, when the project lacks it. The issues are the file's
  (`Igniter.prepare_for_write/1` lifts them, `mix.exs:` before each).
  """
  @spec apply(Igniter.t(), String.t(), String.t(), String.t()) :: Igniter.t()
  def apply(igniter, base, theirs, capability) do
    base_read = read(base)
    delta = diff(base, theirs)

    igniter =
      Enum.reduce(delta.project, igniter, fn {key, code}, igniter ->
        put_keyword(igniter, [key], code, List.keyfind(base_read.project, key, 0), capability)
      end)

    # Reached through `aliases: aliases()` in project: Igniter follows
    # the call to the function, `def` or `defp`, where a path by the
    # function's own name finds only a `def`.
    igniter =
      Enum.reduce(delta.aliases, igniter, fn {key, code}, igniter ->
        put_keyword(
          igniter,
          [:aliases, key],
          code,
          List.keyfind(base_read.aliases, key, 0),
          capability
        )
      end)

    Enum.reduce(delta.deps, igniter, fn {name, code}, igniter -> add_dep(igniter, name, code) end)
  end

  # A keyword set to the capability's code: created when absent, replaced
  # when the project has it as base had it, left — with an issue — when
  # the project has it otherwise: the project's own edit is the project's.
  defp put_keyword(igniter, path, code, in_base, capability) do
    Igniter.Project.MixProject.update(igniter, :project, path, fn
      nil ->
        {:ok, {:code, code}}

      zipper ->
        cond do
          same?(zipper.node, code) ->
            {:ok, zipper}

          in_base != nil and same?(zipper.node, elem(in_base, 1)) ->
            {:ok, {:code, code}}

          true ->
            # Reported on the file: Igniter prefixes the path to it.
            {:error,
             "#{Enum.map_join(path, " ", &inspect/1)} is the project's own — the #{capability} " <>
               "would set it to `#{Macro.to_string(code)}`; the project has " <>
               "`#{Macro.to_string(zipper.node)}`. Set it by hand if you want the #{capability}'s."}
        end
    end)
  end

  # A dependency appended to the list `defp deps` ends in, as code —
  # not through Igniter.Project.Deps.add_dep, which renders a term and
  # would turn `runtime: Mix.env() == :dev` into `runtime: true`.
  defp add_dep(igniter, name, code) do
    if Igniter.Project.Deps.has_dep?(igniter, name),
      do: igniter,
      else: Igniter.update_elixir_file(igniter, "mix.exs", &append_dep(&1, name, code))
  end

  defp append_dep(zipper, name, code) do
    with {:ok, zipper} <- Igniter.Code.Module.move_to_module_using(zipper, Mix.Project),
         {:ok, zipper} <- Igniter.Code.Function.move_to_defp(zipper, :deps, 0),
         zipper <- Zipper.rightmost(zipper),
         true <- Igniter.Code.List.list?(zipper) do
      # Parsed again by Sourceror, so a two-element tuple keeps its
      # braces: a bare `{:swoosh, "~> 1.16"}` at a list's end would
      # print as the keyword `swoosh: "~> 1.16"`.
      Igniter.Code.List.append_to_list(zipper, Sourceror.parse_string!(Macro.to_string(code)))
    else
      _ -> {:error, "`deps/0` does not end in a list literal to add #{inspect(name)} to."}
    end
  end
end
