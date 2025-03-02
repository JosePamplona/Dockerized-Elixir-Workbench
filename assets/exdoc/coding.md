# Elixir coding guidelines

Guide for homogeneous coding with Elixir programming lenguage.

## Source code layout

1. Avoid lines longer than 80 characters.

1. Avoid trailing whitespace.

1. Do not use semicolon to end the line, simply use a line ending.

    ```elixir
    # Not preferred
    some_function();

    # Preferred
    some_function()
    ```

1. Use Unix-style line endings `\n` (Operating systems derived from Unix are covered by default, Windows users have to be extra careful that the line endings were not `\n\r`).

    If you're using Git you might want to add the following configuration setting to protect your project from Windows line endings creeping in:

    ```sh
    git config --global core.autocrlf true
    ```

1. Use two spaces per indentation level. No hard tabs.

    ```elixir
    # Not preferred (4 spaces)
    def some_function do
        do_something()
    end

    # Preferred (2 spaces)
    def some_function do
      do_something()
    end
    ```

1. Use spaces after commas, colons and around operators. Except for unary operators, the operator point and the operator rank (two points). Do not put spaces around matched pairs like brackets, parentheses, etc. Whitespace might be (mostly) irrelevant to the Elixir runtime, but its proper use is the key to writing easily readable code.

    | Style rule | Operators |
    | :--- | :--- |
    | No spaces | `@` `.` `+` `-` `!` `^` `&` `..` `~~~` `()` `[]` `{}` |
    | Space after | `,` `:` `not` |
    | Spaces around | `*` `/` `+` `-` `++` `--` `<>` `in` `not in` `\|>` `<<<` `>>>` `~>>` `<<~` `~>` `<~` `<~>` `<\|>` `<` `>` `<=` `>=` `==` `!=` `=~` `===` `!==` `&&` `&&&` `and` `\|\|` `\|\|\|` `or` `=` `=>` `::` `when` `<-` `\\` |

    > ⚠️ The operators `+` `-` are overloaded, they exist with one-arity and two-arity. When used with one-arity, no spaces are required. When are used with two-arity, spaces are placed around the operator.

    ```elixir
    # Not preferred
    result=2*5
    list =[ 1,<< 2 >> ,3 ]++[4 ,5 ]
    some_string|>String.trim()|>String.split( "-" )

    for num<-list,do: num||0

    num = - 2
    inverse= ! bool
    Enum . map( list, some_function( ) )
    range = 1 .. 10

    def other_function( args,options\\[  ] ),do: some_function( )

    # Preferred
    result = 2 * 5
    list = [1, <<2>>, 3] ++ [4, 5]
    some_string |> String.trim() |> String.split("-")

    for num <- list, do: num || 0

    num = -2
    inverse = !bool
    Enum.map(list, some_function())
    range = 1..10

    def other_function(args, options \\ []), do: some_function()
    ```

1. Use blank lines between `defs` to break up a function into logical paragraphs.

    ```elixir
    # Not preferred
    def some_function(some_data) do
      altered_data = Module.function(data)
    end
    def some_function do
      result
    end
    def some_other_function do
      another_result
    end

    # Preferred
    def some_function(some_data) do
      altered_data = Module.function(data)
    end

    def some_function do
      result
    end

    def some_other_function do
      another_result
    end
    ```

1. Run single-line `defs` that match for the same function together, but separate multiline `defs` with a blank line.

    ```elixir
    # Not preferred
    def some_function(nil), do: {:error, "No Value"}

    def some_function([]), do: :ok

    def some_function([first | rest]), do: some_function(rest)

    # Preferred
    def some_function(nil), do: {:error, "No Value"}
    def some_function([]), do: :ok
    def some_function([first | rest]), do: some_function(rest)

    # Also preferred
    def some_function(nil), do: {:error, "No Value"}
    def some_function([]), do: :ok

    def some_function([first | rest]) do
      some_function(rest)
    end
    ```

1. If the function head and `do:` clause are too long to fit on the same line, put `do:` on a new line, indented one level more than the previous line.

    ```elixir
    # Preferred
    def some_function([:foo, :bar, :baz] = args),
      do: Enum.map(args, fn arg -> arg <> " is on a very long line!" end)
    ```

    When the `do:` clause starts on its own line, treat it as a multiline `def` by separating it with blank lines.

    ```elixir
    # Not preferred
    def some_function([]), do: :empty
    def some_function(_),
      do: :very_long_line_here

    # Preferred
    def some_function([]), do: :empty

    def some_function(_),
      do: :very_long_line_here
    ```

1. If you have more than one multiline `def` matching the same function, do not use single-line `defs`.

    ```elixir
    # Not preferred
    def some_function(nil), do: {:error, "No Value"}
    def some_function([]), do: :ok

    def some_function([first | rest]) do
      some_function(rest)
    end

    def some_function([first | rest], opts) do
      some_function(rest, opts)
    end

    # Preferred
    def some_function(nil) do
      {:error, "No Value"}
    end

    def some_function([]) do
      :ok
    end

    def some_function([first | rest]) do
      some_function(rest)
    end

    def some_function([first | rest], opts) do
      some_function(rest, opts)
    end
    ```

1. Use the pipe operator `|>` to chain functions together.

    ```elixir
    # Not preferred
    String.strip(String.downcase(some_string))

    # Preferred
    some_string |> String.downcase() |> String.strip()

    # Multiline pipelines are not further indented.
    some_string
    |> String.downcase()
    |> String.strip()

    # Multiline pipelines on the right side of a pattern match should be
    # indented on a new line.
    sanitized_string =
      some_string
      |> String.downcase()
      |> String.strip()
    ```

    While this is the preferred method, take into account that copy-pasting multiline pipelines into IEx might result in a syntax error, as IEx will evaluate the first line without realizing that the next line has a pipeline.

1. Use bare expresions in the first part of a function chain.

    ```elixir
    # THE WORST!
    # This actually parses as:
    # String.strip("nope" |> String.downcase())
    String.trim "nope" |> String.downcase()

    # Not preferred
    String.trim(some_string) |> String.downcase() |> String.codepoints()

    # Preferred
    some_string |> String.trim() |> String.downcase() |> String.codepoints()
    ```

1. Avoid using the pipe operator `|>` just once.

    ```elixir
    # Not preferred
    some_string |> String.downcase()

    # Preferred
    String.downcase(some_string)
    ```

1. Use parentheses for one-arity functions when using the pipe operator `|>`.

    ```elixir
    # Not preferred
    some_string |> String.downcase |> String.strip

    # Preferred
    some_string |> String.downcase() |> String.strip()
    ```

1. Do not use anonymous functions in pipelines.

    ```elixir
    # Not preferred
    some_string
    |> String.trim()
    |> String.downcase()
    |> (fn string -> string <> "_OK" end).()
    |> String.split("-")

    # Preferred
    some_string
    |> String.trim()
    |> String.downcase()
    |> review()
    |> String.split("-")

    def review(string), do: string <> "_OK"
    ```

1. When `case` or `cond` clauses span multiple lines, separate each clause with a blank line.

    ```elixir
    # Not preferred
    case arg do
      true ->
        :ok
      false ->
        :error
    end

    # Preferred
    case arg do
      true ->
        :ok

      false ->
        :error
    end
    ```

1. If a *list*, *tuple*, *map*, or *struct* spans multiple lines, put each element, as well as the opening and closing brackets, on its own line. Indent each element one level, but not the brackets.

    ```elixir
    # Not preferred
    [:first_item, :second_item, :next_item,
    :final_item]

    # Preferred
    [
      :first_item,
      :second_item,
      :next_item,
      :final_item
    ]
    ```

1. When assigning a *list*, *tuple*, *map*, or *struct*, keep the opening bracket on the same line as the assignment.

    ```elixir
    # Not preferred
    list =
    [
      :first_item,
      :second_item
    ]

    # Preferred
    list = [
      :first_item,
      :second_item
    ]
    ```

1. After a multiline assignment add a blank line as separation.

    ```elixir
    # Not preferred
    some_string =
      "Hello"
      |> String.downcase()
      |> String.strip()
    another_string <> some_string

    # Preferred
    some_string =
      "Hello"
      |> String.downcase()
      |> String.strip()

    another_string <> some_string
    ```

1. Add underscores to decimal literals that have six or more digits.

    ```elixir
    # Not preferred
    num = 1000000
    num = 1_500

    # Preferred
    num = 1_000_000
    num = 1500
    ```

1. Use uppercase letters when using hex literals.

    ```elixir
    # Not preferred
    <<0xef, 0xbb, 0xbf>>

    # Preferred
    <<0xEF, 0xBB, 0xBF>>
    ```

1. End each file with a newline.

## Syntax

1. Use parentheses when a `def` structure has arguments, and omit them when it doesn't.

    ```elixir
    # Not preferred
    def some_function arg1, arg2 do
      ...
    end

    def some_function() do
      ...
    end

    # Preferred
    def some_function(arg1, arg2) do
      ...
    end

    def some_function do
      ...
    end
    ```

1. Never put a space between a function name and the opening parenthesis.

    ```elixir
    # Not preferred
    f (3 + 2)

    # Preferred
    f(3 + 2)
    ```

1. Use always parentheses in function calls, especially inside a pipeline and in functions that do not receive arguments so they can be distinguished from variables. Starting in Elixir 1.4, the compiler will warn you about locations where this ambiguity exists.

    ```elixir
    # Not preferred
    f 3

    Enum.reduce 1..100, 0, fn x, acc ->
      x + acc
    end

    # This actually parses as: rem(2, (3 |> g()))
    2 |> rem 3 |> g

    def my_func do
      # Is this a variable or a function call?
      do_stuff
    end

    # Preferred
    f(3)

    Enum.reduce(1..100, 0, fn(x, acc) ->
      x + acc
    end)

    2 |> rem(3) |> g()

    def my_func do
      # This is clearly a function call.
      do_stuff()
    end
    ```

1. For macros we see the contrary behaviour. The preferred way is to not use parentheses.

    ```elixir
    # Not preferred
    if( valid?(username) ) do
      ...
    end

    defmodule( MyApp.Service.TwitterAPI ) do
      use MyApp.Service, social: true

      alias MyApp.Service.Helper, as: H
    end

    # Preferred
    if valid?(username) do
      ...
    end

    defmodule MyApp.Service.TwitterAPI do
      use MyApp.Service, social: true

      alias MyApp.Service.Helper, as: H
    end
    ```

1. Use `do:` syntaxis for single line macros statement.

    ```elixir
    # Preferred
    if some_condition, do: # some_stuff
    ```

1. If the arguments of a macro make the line too long, indent and align the successive arguments. Place the `do:` in a new line with one indentation level.

    ```elixir
    # Preferred
    with {:ok, foo} <- Keyword.fetch(opts, :foo),
         {:ok, bar} <- Keyword.fetch(opts, :bar),
      do: {:ok, foo, bar}
    ```

1. If the macro has a `do` block with more than one line, or has an `else` option, use multiline syntax.

    ```elixir
    # Preferred
    with {:ok, foo} <- Keyword.fetch(opts, :foo),
         {:ok, bar} <- Keyword.fetch(opts, :bar) do
      {:ok, foo, bar}
    else
      :error ->
        {:error, :bad_arg}
    end
    ```

1. Never use `unless` with `else`. Rewrite these with the positive case first with an `if` construct.

    ```elixir
    # Not preferred
    unless success do
      IO.puts('failure')
    else
      IO.puts('success')
    end

    # Preferred
    if success do
      IO.puts('success')
    else
      IO.puts('failure')
    end
    ```

1. Omit the `else` option in `if` and `unless` constructs if `else` returns **nil**.

    ```elixir
    # Not preferred
    if byte_size(data) > 0, do: data, else: nil

    # Preferred
    if byte_size(data) > 0, do: data
    ```

1. Use **true** as the last condition of the `cond` special form when you need a clause that always matches.

    ```elixir
    # Not preferred
    cond do
      1 + 2 == 5 ->
        "Nope"

      1 + 3 == 5 ->
        "Uh, uh"

      :else ->
        "OK"
    end

    # Preferred
    cond do
      1 + 2 == 5 ->
        "Nope"

      1 + 3 == 5 ->
        "Uh, uh"

      true ->
        "OK"
    end
    ```

1. Use `or`, `and` and `not` for strictly boolean checks. Use `||`, `&&`, and `!` operators only if any of the arguments are non-boolean.

    ```elixir
    # Not preferred
    is_atom(name) && name != nil
    is_binary(task) || is_atom(task)

    # Preferred
    is_atom(name) and name != nil
    is_binary(task) or is_atom(task)
    line && line != 0
    file || "sample.exs"
    ```

1. Always use the special syntax for *keyword* lists.

    ```elixir
    # Not preferred
    some_value = [{:a, "baz"}, {:b, "qux"}]

    # Preferred
    some_value = [a: "baz", b: "qux"]
    ```

1. Omit square brackets from *keyword* lists whenever they are optional.

    ```elixir
    # Not preferred
    some_function(foo, bar, [a: "baz", b: "qux"])

    # Preferred
    some_function(foo, bar, a: "baz", b: "qux")
    ```

## Naming

1. Use *snake case* for naming directories and files, for example: `lib/my_app/task_server.ex`.

1. Use *upper camel case* for modules (keep acronyms like HTTP, RFC, XML uppercase).

    ```elixir
    # Not preferred
    defmodule Somemodule do
      ...
    end

    defmodule Some_Module do
      ...
    end

    defmodule SomeXml do
      ...
    end

    # Preferred
    defmodule SomeModule do
      ...
    end

    defmodule SomeXML do
      ...
    end
    ```

1. Use *snake case* for *atoms*, functions and variables.

    ```elixir
    # Not preferred
    :"some atom"
    :SomeAtom
    :someAtom

    someVar = 5

    def someFunction do
      ...
    end

    # Preferred
    :some_atom

    some_var = 5

    def some_function do
      ...
    end
    ```

1. The names of macros (compile-time generated functions that return a boolean value) that can be used within *guards* should be prefixed with "is_".

    ```elixir
    # Preferred
    defmacro is_cool(var) do
      quote do: unquote(var) == "cool"
    end
    ```

1. The names of functions that return a boolean value should have a trailing question mark "?" rather than the "is_" prefix.

    ```elixir
    # Preferred
    def cool?(var) do
      ...
    end
    ```

1. The private functions with the same name as public functions should have the "do_" prefix.

    ```elixir
    # Preferred
    def sum(list), do: do_sum(list, 0)

    defp do_sum([], total), do: total
    defp do_sum([head | tail], total), do: do_sum(tail, head + total)
    ```

## Comments

1. Write expressive code and try to convey your program's intention through control-flow, structure and naming.

1. Place comments above the line they comment on.

    ```elixir
    String.first(some_string) # Not preferred

    # Preferred
    String.first(some_string)
    ```

1. Use one space between the leading "#" character of the comment and the text of the comment.

    ```elixir
    #Not preferred
    String.first(some_string)

    # Preferred
    String.first(some_string)
    ```

1. Comments longer than a word are capitalized, and sentences use punctuation. Use one space after periods.

    ```elixir
    # Not preferred
    # these lowercase comments are missing punctuation

    # Preferred
    # Capitalization example: Use punctuation for complete sentences.
    ```

### Comment Annotations

1. The annotation keyword is uppercase, and is followed by a colon and a space, then a note describing the problem.

    ```elixir
    # Preferred
    # TODO: Deprecate in v1.5.
    def some_function(arg), do: {:ok, arg}
    ```

1. In cases where the problem is so obvious that any documentation would be redundant, annotations may be left with no note. This usage should be the exception and not the rule.

    ```elixir
    start_task()

    # FIXME
    Process.sleep(5000)
    ```

1. Use `TODO` to note missing features or functionality that should be added at a later date

1. Use `FIXME` to note broken code that needs to be fixed.

1. Use `OPTIMIZE` to note slow or inefficient code that may cause performance problems.

1. Use `HACK` to note code smells where questionable coding practices were used and should be refactored away.

1. Use `REVIEW` to note anything that should be looked at to confirm it is working as intended.

    ```elixir
    # REVIEW: Are we sure this is how the client does X currently?
    ```

1. Use other custom annotation keywords if it feels appropriate, but be sure to document them in your project's README or similar.

## Modules

1. Use one module per file unless the module is only used internally by another module (such as a test).

1. Use *snake case* file names for *upper camel case* module names.

    ```elixir
    # Preferred
    # file is called: some_module.ex

    defmodule SomeModule do
    end
    ```

1. Represent each level of nesting within a module name as a directory.

    ```elixir
    # Preferred
    # file is called: parser/core/xml_parser.ex

    defmodule Parser.Core.XMLParser do
    end
    ```

1. Don't put a blank line after `defmodule`.

    ```elixir
    # Not preferred
    defmodule System.Accounts do

      import Ecto.Query, warn: false
      ...
    end

    # Preferred
    defmodule System.Accounts do
      import Ecto.Query, warn: false
      ...
    end
    ```

1. Put a blank line after module-level code blocks.

1. List module attributes and directives in the following order:

    1. `@moduledoc`
    1. `@behaviour`
    1. `use`
    1. `import`
    1. `alias`
    1. `require`
    1. `defstruct`
    1. `@type`
    1. `@module_attribute`
    1. `@callback`
    1. `@macrocallback`
    1. `@optional_callbacks`

1. Add a blank line between each grouping, and sort the terms (like module names) alphabetically. Here's an overall example of how you should order things in your modules:

    ```elixir
    # Preferred
    defmodule MyModule do
      @moduledoc """
      An example module
      """

      @behaviour MyBehaviour

      use GenServer

      import Something
      import SomethingElse

      alias My.Long.Module.Name
      alias My.Other.Module.Example

      require Integer

      defstruct name: nil, params: []

      @type params :: [{binary, binary}]

      @module_attribute :foo
      @other_attribute 100

      @callback some_function(term) :: :ok | {:error, term}

      @macrocallback macro_name(term) :: Macro.t()

      @optional_callbacks macro_name: 1

      ...
    end
    ```

1. Use the `__MODULE__` pseudo variable when a module refers to itself. This avoids having to update any self-references when the module name changes.

    ```elixir
    # Preferred
    defmodule SomeProject.SomeModule do
      defstruct [:name]

      def name(%__MODULE__{name: name}), do: name
    end
    ```

    If you want a prettier name for a module self-reference, set up an alias.

    ```elixir
    # Preferred
    defmodule SomeProject.SomeModule do
      alias __MODULE__, as: SomeModule

      defstruct [:name]

      def name(%SomeModule{name: name}), do: name
    end
    ```

1. Avoid repeating fragments in module names and namespaces. This improves overall readability and eliminates ambiguous aliases.

    ```elixir
    # Not preferred
    defmodule Todo.Todo do
      ...
    end

    # Preferred
    defmodule Todo.Item do
      ...
    end
    ```

## Functions

1. If a function receives options, they must be grouped into a *keyword list* as the last argument, and with the operator `\\` an empty list will be assigned as default. Each option will have its own variable, wich is assigned the value of the corresponding *keyword* in the options argument with the `Keyword.get` method, or a default value in the case of not being provided.

    ```elixir
    # Not preferred
    def some_function(arg, opt1 \\ "Default value 1", opt2 \\ 255, opt3 \\ false) do
      ...
    end

    # Preferred
    def some_function(arg, options \\ []) do
      opt1 = Keyword.get(options, :opt1, "Default value 1")
      opt2 = Keyword.get(options, :opt2, 255)
      opt3 = Keyword.get(options, :opt3, false)

      ...
    end
    ```

## Documentation

Documentation in Elixir (when read either in IEx with h or generated with ExDoc) uses the Module Attributes `@moduledoc` and `@doc`.

1. Use `@moduledoc false` if you do not intend on documenting the module.

    ```elixir
    # Not preferred
    defmodule SomeModule do
      ...
    end

    # Preferred
    defmodule SomeModule do
      @moduledoc false
      ...
    end
    ```

1. Separate code after the `@moduledoc` with a blank line.

    ```elixir
    # Not preferred
    defmodule SomeModule do
      @moduledoc """
      About the module
      """
      use AnotherModule
    end

    # Preferred
    defmodule SomeModule do
      @moduledoc """
      About the module
      """

      use AnotherModule
    end
    ```

1. Use *heredocs strings* with markdown for documentation.

    ```elixir
    # Not preferred
    defmodule SomeModule do
      @moduledoc "About the module"
    end

    defmodule SomeModule do
      @moduledoc """
      About the module

      Examples:
      iex> SomeModule.some_function
      :result
      """
    end

    # Preferred
    defmodule SomeModule do
      @moduledoc """
      About the module

      ## Examples

          iex> SomeModule.some_function
          :result
      """
    end
    ```

## Typespecs

Typespecs are notation for declaring types and specifications, for documentation or for the static analysis tool Dialyzer.

Custom types should be defined at the top of the module with the other directives.

1. Place `@typedoc` and `@type` definitions together, and separate each pair with a blank line.

    ```elixir
    # Preferred
    defmodule SomeModule do
      @moduledoc false

      @typedoc "The name"
      @type name :: atom

      @typedoc "The result"
      @type result :: {:ok, term} | {:error, term}

      ...
    end
    ```

1. If a union type is too long to fit on a single line, put each part of the type on a separate line, indented one level past the name of the type.

    ```elixir
    # Not preferred
    @type long_union_type :: some_type | another_type | some_other_type |
    a_final_type

    # Preferred
    @type long_union_type ::
            some_type
            | another_type
            | some_other_type
            | a_final_type
    ```

1. Name the main type for a module t, for example: the type specification for a *struct*.

    ```elixir
    # Preferred
    defstruct name: nil, params: []

    @type t :: %__MODULE__{
            name: String.t() | nil,
            params: Keyword.t()
          }
    ```

1. Place specifications right before the function definition, without separating them by a blank line.

    ```elixir
    # Not preferred
    @spec some_function(term) :: result

    def some_function(some_data) do
      {:ok, some_data}
    end

    # Preferred
    @spec some_function(term) :: result
    def some_function(some_data) do
      {:ok, some_data}
    end
    ```

## Structs

1. Use a list of *atoms* for *struct* fields that default to **nil**, followed by the other *keywords*.

    ```elixir
    # Not preferred
    defstruct name: nil, params: nil, active: true

    # Preferred
    defstruct [:name, :params, active: true]
    ```

1. Omit square brackets when the argument of a `defstruct` is a *keyword* list. Brackets will not be omitted if there is at least one *atom* in the list.

    ```elixir
    # Not preferred
    defstruct [params: [], active: true]

    # Preferred
    defstruct params: [], active: true

    # Required - Brackets are not optional, with at least one atom in the list.
    defstruct [:name, params: [], active: true]
    ```

1. If a *struct* definition spans multiple lines, put each element on its own line, keeping the elements aligned.

    ```elixir
    # Not preferred
    defstruct foo: "test", bar: true, baz: false,
      qux: false, quux: 1

    # Preferred
    defstruct foo: "test",
              bar: true,
              baz: false,
              qux: false,
              quux: 1
    ```

1. If a multiline *struct* requires brackets, format it as a multiline list:

    ```elixir
    # Preferred
    defstruct [
      :name,
      params: [],
      active: true
    ]
    ```

## Exceptions

1. Make exception names end with a trailing "Error".

    ```elixir
    # Not preferred
    defmodule BadHTTPCode do
      defexception [:message]
    end

    defmodule BadHTTPCodeException do
      defexception [:message]
    end

    # Preferred
    defmodule BadHTTPCodeError do
      defexception [:message]
    end
    ```

1. Use lowercase error messages when raising exceptions, with no trailing punctuation.

    ```elixir
    # Not preferred
    raise ArgumentError, "This is not valid."

    # Preferred
    raise ArgumentError, "this is not valid"
    ```

## Strings

1. Match *strings* using the string concatenator rather than binary patterns:

    ```elixir
    # Not preferred
    <<"my"::utf8, _rest::bytes>> = "my string"

    # Preferred
    "my" <> _rest = "my string"
    ```

## Testing

1. When writing ExUnit assertions, be consistent with the order of the expected and actual values under testing. Prefer placing the expected result on the right, unless the assertion is a *pattern match*.

    ```elixir
    # Not preferred - Inconsistent order.
    assert actual_function(1) == true
    assert false == actual_function(2)

    # Preferred - Expected result on the right.
    assert actual_function(1) == true
    assert actual_function(2) == false

    # Required - The assertion is a pattern match.
    assert {:ok, expected} = actual_function(3)
    ```

## License

![Creative Commons License](http://i.creativecommons.org/l/by/3.0/88x31.png) This work is licensed under a [Creative Commons Attribution 3.0 Unported License](https://creativecommons.org/licenses/by/3.0/deed.en_US).

### Attribution

The structure of this guide, bits of example code, and many of the initial points made in this document were borrowed from [Christopher Adams'](https://github.com/christopheradams/elixir_style_guide), [Alberto Almargo's](https://github.com/albertoalmagro/elixir_style_guide), [Aleksei Magusev's](https://github.com/lexmag/elixir-style-guide) and [Credo's](https://github.com/rrrene/elixir-style-guide) Elixir style guides.