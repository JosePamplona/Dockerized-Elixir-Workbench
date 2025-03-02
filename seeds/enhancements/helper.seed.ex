defmodule %{elixir_module}.Helper do
  @moduledoc """
  Module for handling standard pagination, and changeset logic tools.

  Provides functions to retrieve standarized paginated resource lists from the
  database, and traverse check for specific fields errors in changesets.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias %{elixir_module}.Repo

  @limit_default 15
  @limit_max     250
  @field_default "inserted_at"
  @order_default "asc"

  @doc """
    Gets a paginated list of resources from the database based on the given
    query.

    The `attrs` parameter must be a map of string type keys which:
    * `"limit"`: Number of records to return in a page.
      * If the key does not exist it will be set to #{@limit_default} by default.
      * If the key value does not represent an integer it will be set to #{@limit_default} by default.
      * If the key value is > #{@limit_max} it will be set to #{@limit_max} by default.
      * If the key value is < 1 it will be set to 1 by default.

    * `"offset"`: Number of pages to skip.
      * If the key does not exist it will be set to 0 by default.
      * If the key value does not represent an integer it will be set to 0 by default.
      * If the key value is < 0 it will be set to 0.

    * `"field"`:  Specifies which field to use when sorting the results.
      * If the key does not exist it will be set to  "inserted_at" by default.
      * If the key value does not represent an existing schema field, it will be set to  "inserted_at" by default.

    * `"order"`: Determines the sorting direction of the results. Accepts "asc" for ascending or "desc" for descending order.
      * If the key does not exist it will be set to  "asc" by default.
      * If the key value is not  "asc" or  "desc" it will be set to "asc" by default.

    ##  Example
        iex> Helper.paginate(User)
        %{
          records: [
            %User{},
            %User{},
            %User{}
          ],
          count: 3,
          page: 1,
          total_count: 3,
          total_pages: 1,
          query: %{limit: 15, offset: 0, order: "asc", field: "inserted_at"}
        }
        
    """

  @spec paginate(query :: module | Ecto.Query.t, attrs :: map) :: map
  def paginate(query, attrs \\ %{}) do
    {_table, schema} = query.from.source
    {limit, offset} = get_page_params(attrs)
    {order, field} = get_order_params(attrs, schema)

    records =
      query
      |> limit([_record], ^limit)
      |> offset([_record], ^(offset * limit))
      |> order_by([_record], [{^order, ^field}])
      |> Repo.all()

    total_count =
      query
      |> select([record], count(record.id))
      |> Map.put(:order_bys, [])
      |> Repo.one()

    %{
      records:     records,
      count:       length(records),
      total_count: total_count,
      page:        offset + 1,
      total_pages: (total_count / limit) |> ceil(),
      query: %{
        limit:  limit,
        offset: offset,
        order:  order,
        field:  field
      }
    }
  end

  @doc """
    Returns boolean indicating if the changeset is valid, traversing the
    changset looking for any errors.

    ##  Example
        iex> changeset = %Changeset(valid?: false)
        iex> Helper.errors_on?(changeset)
        true

        iex> changeset = %Changeset(valid?: true)
        iex> Helper.errors_on?(changeset)
        false
    """

  @spec errors_on?(changeset :: Changeset.t) :: boolean
  def errors_on?(%Changeset{} = changeset) do
    changeset
    |> Changeset.traverse_errors(&(&1))
    |> Map.keys()
    |> case do
      [] -> false
      _  -> true
    end
  end

  @doc """
    Returns boolean indicating if the changeset is valid, traversing the
    changset errors and checking only for specified field errors.

    Returns `true` if the changset have an error attributed to the given
    changeset field or the given list of fields.

    Returns `false` if the changeset does not have an error attributed to the
    given changeset field or the given list of fields.

    ##  Example
        iex> changeset = %Changeset(errors: [field: {"is invalid", []}])
        iex> Helper.errors_on?(changeset, :field)
        true

        iex> changeset = %Changeset(errors: [])
        iex> Helper.errors_on?(changeset, :field)
        false

        iex> changeset = %Changeset(errors: [field_02: {"is invalid", []}])
        iex> Helper.errors_on?(changeset, [:field_01, :field_02, :field_03])
        true

        iex> changeset = %Changeset(errors: [field_04: {"is invalid", []}])
        iex> Helper.errors_on?(changeset, [:field_01, :field_02, :field_03])
        false
    """

  @spec errors_on?(changeset :: Changeset.t, field :: atom | [atom] | nil) ::
    boolean
  def errors_on?(%Changeset{} = changeset, field) when is_atom(field), do:
    errors_on?(changeset, [field])

  def errors_on?(%Changeset{} = changeset, fields) when is_list(fields) do
    changeset
    |> Changeset.traverse_errors(&(&1))
    |> Enum.any?(fn {field, _} -> field in fields end)
  end

  # --- Private ----------------------------------------------------------------

  # These `get_***_params()` functions normalizes the given paramaters
  # (present or not) in order to set them on pagination queries.

  defp get_page_params(attrs) when is_map(attrs) do
    limit =
      attrs
      |> Map.get("limit", "")
      |> Integer.parse()
      |> case do
        {int, ""} when int > @limit_max -> @limit_max
        {int, ""} when int > 0 -> int
        {int, ""} when int < 0 -> 1
        _ -> @limit_default
      end

    offset =
      attrs
      |> Map.get("offset", "")
      |> Integer.parse()
      |> case do
        {int, ""} when int >= 0 -> int
        _ -> 0
      end

    {limit, offset}
  end

  defp get_order_params(attrs, schema) when is_map(attrs) do
    schema_fields = for(field <- schema.__schema__(:fields), do: "#{field}")
    field = Map.get(attrs, "field", @field_default)
    field =
      case field in schema_fields do
        true  -> String.to_existing_atom(field)
        false -> String.to_existing_atom(@field_default)
      end

    order =
      attrs
      |> Map.get("order", @order_default)
      |> case do
        "asc"  -> :asc
        "desc" -> :desc
        _      -> String.to_atom(@order_default)
      end

    {order, field}
  end
end
