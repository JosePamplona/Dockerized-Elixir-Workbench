defmodule %{elixir_module}Web.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  # <!-- workbench-ecto open -->
  alias Ecto.Changeset

  # <!-- workbench-ecto close -->
  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".

  @doc """
    Default HTTP errors render.

    Renders an error response body containing the Phoenix default HTTP error
    message.

    ## Example
        iex> %{elixir_module}Web.ErrorJSON.render("404.json", %{})
        %{error: "Not Found"}

        iex> %{elixir_module}Web.ErrorJSON.render("500.json", %{})
        %{error: "Internal Server Error"}
    """

  @spec render(template :: binary, _assigns :: term) :: %{error: binary}
  def render(template, _assigns) do
    message = Phoenix.Controller.status_message_from_template(template)
    %{error: message}
  end

  # <!-- workbench-ecto open -->
  @doc """
    Standard changeset errors render.

    Renders an error response body containing all traversed errors present in the changeset, including the embedded changesets.

    ## Example
        iex> %{elixir_module}Web.ErrorJSON.error(%{changeset: %Changeset{}})
        %{error: %{
          field_01: ["is invalid"],
          field_02: ["can't be blank"]
        }}
    """

  @spec error(%{changeset: changeset :: Changeset.t}) :: %{error: map}
  def error(%{changeset: changeset}) do
    errors =
      Changeset.traverse_errors(changeset, fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _, key ->
          # coveralls-ignore-start
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          # coveralls-ignore-stop
        end)
      end)

    %{error: errors}
  end

  @spec error(%{message: message :: binary}) :: %{error: binary}
  def error(%{message: message}), do: %{error: message}
  # <!-- workbench-ecto close -->
end
