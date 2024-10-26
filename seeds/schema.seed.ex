defmodule %{elixir_module}.EctoSchema do
  @moduledoc false
  
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      
      import Ecto.Changeset
      import EctoEnum

      alias %{elixir_module}.Repo

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
    fields = fields ++ [__meta__: meta_module]
    key_types =
      for {field, type} <- fields do {field, type_to_spec(type)} end

    quote do
      @type t :: %__MODULE__{unquote_splicing(key_types)}
    end
  end
  
  defp type_to_spec(:boolean),             do: quote(do: boolean)
  defp type_to_spec(:integer),             do: quote(do: integer)
  defp type_to_spec(:map),                 do: quote(do: map)
  defp type_to_spec(:string),              do: quote(do: String.t)
  defp type_to_spec(:naive_datetime_usec), do: quote(do: NaiveDateTime.t)
  defp type_to_spec({:array, type}) do
    quote(do: [unquote(type_to_spec(type))])
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
