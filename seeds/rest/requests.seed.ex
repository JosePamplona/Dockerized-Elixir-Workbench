defmodule %{elixir_module}Web.OpenApi.Requests do
  @moduledoc false

  alias OpenApiSpex.Schema

  @request_type "application/json"

  def security, do: [%{"authorization" => []}]

  def request_body(schema, instructions \\ "") do
    {instructions, @request_type, schema}
  end

  def pagination_query_params do
    [
      limit: [
        in: :query,
        description: """
          Specifies the maximum number of results to return in a single response. It controls the page size.\n
          <small>__e.g.:__ ___&limit=25___ means return only 25 records.</small>
          """,
        schema: %Schema{
          type: :integer,
          default: 15,
          minimum: 1,
          maximum: 250
        },
        example: 25
      ],
      offset: [
        in: :query,
        description: """
          Zero-indexed integer representing the number of records to skip before starting to return results. It calculates the starting point by multiplying offset and limit, enabling systematic retrieval from large datasets.\n
          <small>__e.g.:__ ___&limit=10?offset=2___ means return records starting from the 21st item, retrieving the next 10 records.</small>
          """,
        schema: %Schema{
          type: :integer,
          minimum: 0
        },
        example: 0
      ],
      field: [
        in: :query,
        description: """
          Specifies which field to use when sorting the results. Must be an existing field name in the schema. If none or an invalid one are given, it will be set as "inserted_at" by default.\n
          """,
        schema: %Schema{
          type: :string,
        },
        example: "inserted_at"
      ],
      order: [
        in: :query,
        description: """
          Determines the sorting direction of the results. Accepts "asc" for ascending or "desc" for descending order. If none or an invalid one are given, it will be set as "asc" by default.\n
          <small>__e.g.:__ ___&field=inserted_at&order=desc___ returns newest records first.</small>
          """,
        schema: %Schema{
          type: :string,
          format: :enum,
          enum: [:asc, :desc]
        },
        example: "asc"
      ]
    ]
  end

  # <!-- workbench-openai open -->
  def assistant_query_params do
    [
      model: [
        in: :query,
        description: """
          Specifies the model to use for generating responses. It must be a valid OpenAI model, such as "gpt-4o-mini" or "gpt-3.5-turbo".\n
          Full models list: <a href="https://platform.openai.com/docs/models" target="_blank">https://platform.openai.com/docs/models</a>
          """,
        schema: %Schema{
          type: :string,
          default: "gpt-4o-mini",
        },
        example: "gpt-4o-mini"
      ],
      temperature: [
        in: :query,
        description: """
          Controls the randomness of responses. A value close to 0 makes responses more deterministic, while a value near 1 makes them more diverse.
          """,
        schema: %Schema{
          type: :float,
          default: 0.7,
          minimum: 0,
          maximum: 1
        },
        example: 0.7
      ],
      max_tokens: [
        in: :query,
        description: """
          Specifies the maximum number of tokens in the response. Lower values limit the response length.
          """,
        schema: %Schema{
          type: :integer,
          default: 512,
          minimum: 1
        },
        example: 512
      ]
    ]
  end
  # <!-- workbench-openai close -->
end
