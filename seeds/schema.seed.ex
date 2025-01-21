defmodule %{elixir_module}.EctoSchema do
  @moduledoc false
  
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      
      import Ecto.Changeset
      import EctoEnum

      alias %{elixir_module}.Repo
      <!-- workbench-auth0 open -->
      alias %{elixir_module}.EctoURI
      <!-- workbench-auth0 close -->

      @primary_key {:id, %{id_type}, autogenerate: true}
      @foreign_key_type %{id_type}
      @timestamps_opts [type: :%{timestamps_type}]
      @derive {Jason.Encoder, except: [:__meta__]}
      <!-- workbench-exdoc open -->

      @before_compile %{elixir_module}.EctoSchema
      <!-- workbench-exdoc close -->
    end
  end
  <!-- workbench-exdoc open -->

  # coveralls-ignore-start
  defmacro __before_compile__(env) do
    %meta_module{} = Module.get_attribute(env.module, :__struct__).__meta__
    fields = Module.get_attribute(env.module, :ecto_fields)
    fields = fields ++ Module.get_attribute(env.module, :ecto_virtual_fields)
    fields = fields ++ Module.get_attribute(env.module, :ecto_assocs)
    fields = fields ++ [__meta__: {meta_module, :always}]
    key_types =
      for {field, {type, _}} <- fields do {field, type_to_spec(type)} end

    quote do
      @type t :: %__MODULE__{unquote_splicing(key_types)}
    end
  end
  
  defp type_to_spec(:id),                  do: quote(do: term)
  defp type_to_spec(:boolean),             do: quote(do: boolean)
  defp type_to_spec(:integer),             do: quote(do: integer)
  defp type_to_spec(:map),                 do: quote(do: map)
  defp type_to_spec(:string),              do: quote(do: binary)
  defp type_to_spec(:naive_datetime_usec), do: quote(do: NaiveDateTime.t)
  defp type_to_spec(:naive_datetime),      do: quote(do: NaiveDateTime.t)
  defp type_to_spec(:datetime_usec),       do: quote(do: DateTime.t)
  defp type_to_spec(:datetime),            do: quote(do: DateTime.t)
  defp type_to_spec({:array, type}) do
    quote(do: [unquote(type_to_spec(type))])
  end
  defp type_to_spec({:parameterized, {Ecto.Enum, %{on_cast: on_cast}}}) do
    atoms = Enum.map(on_cast, fn {_k, v} -> v end)
    
    types = atoms
      |> Enum.reverse()
      |> Enum.reduce(fn(atom, acc) -> {:|, [], [atom, acc]} end)
      
    quote(do: unquote(types))
  end
    
  defp type_to_spec(%{related: module, cardinality: :one}) do
    quote(do: unquote(module).t)
  end

  defp type_to_spec(%{related: module, cardinality: :many}) do
    quote(do: [unquote(module).t])
  end

  defp type_to_spec(module) when is_atom(module) do
    quote(do: unquote(module).t)
  end

  defp type_to_spec(_), do: quote(do: any)
  # coveralls-ignore-stop
  <!-- workbench-exdoc close -->
end
