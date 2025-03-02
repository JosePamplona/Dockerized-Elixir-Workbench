defmodule LoremIpsum.Schema do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      
      import Ecto.Changeset
      import Ecto.Query, warn: false
      import EctoEnum
      import LoremIpsum.Helper

      alias LoremIpsum.EctoURI
      alias LoremIpsum.Repo

      @primary_key {:id, Ecto.UUID, autogenerate: true}
      @foreign_key_type Ecto.UUID
      @timestamps_opts [type: :naive_datetime_usec]

      @before_compile LoremIpsum.Schema

      defimpl Jason.Encoder do
        def encode(input, opts) do
          input
          |> Map.drop([:__struct__, :__meta__])
          |> Enum.reject(fn
            {_k, %Ecto.Association.NotLoaded{}} -> true
            _ -> false
          end)
          |> Enum.into(%{})
          |> Jason.Encode.map(opts)
        end
      end
    end
  end

  # coveralls-ignore-start
  defmacro __before_compile__(env) do
    %meta_module{} = Module.get_attribute(env.module, :__struct__).__meta__
    fields = Module.get_attribute(env.module, :ecto_fields)
    fields = fields ++ Module.get_attribute(env.module, :ecto_virtual_fields)
    fields = fields ++ Module.get_attribute(env.module, :ecto_assocs)
    fields = fields ++ [__meta__: {meta_module, :always}]
    key_types =
      for {field, type} <- fields do
        type = case type do
          {type, :always} -> type
          %{} = type -> type
        end
        
        {field, type_to_spec(type)}
      end

    quote do
      @type t :: %__MODULE__{unquote_splicing(key_types)}
    end
  end

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
end
