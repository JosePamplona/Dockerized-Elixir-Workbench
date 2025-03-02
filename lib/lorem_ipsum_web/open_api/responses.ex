defmodule LoremIpsumWeb.OpenApi.Responses do
  @moduledoc false

  alias OpenApiSpex.{Example, MediaType, Response, Schema}

  @response_type "application/json"
  @defaults %{
    {400, # Invalid HTTP Error code
      %{
        # Endpoint description
        description: """
          Invalid request body response. The server could not process the request due to invalid format or missing required parameters. This response includes details of the error, such as the invalid fields. This errors messages are meant to be read by the user which should use this information to correct and resend the request.
          """,
        # Endpoint response body
        schema: %Schema{
          type: :object,
          description: "Invalid request body response.",
          properties: %{
            error: %Schema{
              type: :object,
              description: "Each key represents a request body field with issues, and the value is a list of strings providing information about the issue(s) in that field.",
              properties: %{
                field: %Schema{
                  type: :array,
                  items: %Schema{
                    type: :string,
                    description: "Field issue message."
                  }
                }
              }
            }
          },
          example: %{error: %{field: ["some error"]}}
        }
      }
    },
    {401, # Unauthorized HTTP Error code
      %{
        # Endpoint description
        description: """
          Unauthorized error response. The request requires valid authentication credentials, which were either missing or incorrect.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Unauthorized error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Unauthorized"}
        }
      }
    },
    {403, # Forbidden HTTP Error code
      %{
        # Endpoint description
        description: """
          Forbidden error response. The request has valid authentication credentials, though access has been denied due to permission rules.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Forbidden error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Forbidden"}
        }
      }
    },
    {404, # Not Found HTTP Error code
      %{
        # Endpoint description
        description: """
          Not Found error response. Indicates the requested resource or endpoint does not exist on the server.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Not Found error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Not Found"}
        }
      }
    },
    {422, # Unprocessable HTTP Error code
      %{
        # Endpoint description
        description: """
          Unprocessable error response. The request has valid authentication credentials, has valid format, syntax and values, but the data has no sense or valid bussines logic (semantic errors).
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Invalid request body response.",
          properties: %{
            error: %Schema{
              type: :object,
              description: "Each key represents a request body field with issues, and the value is a list of strings providing information about the issue(s) in that field.",
              properties: %{
                field: %Schema{
                  type: :array,
                  items: %Schema{
                    type: :string,
                    description: "Field issue message."
                  }
                }
              }
            }
          },
          example: %{error: %{field: ["some error"]}}
        }
      }
    },
    {429, # Too Many Requests HTTP Error code
      %{
        # Endpoint description
        description: """
          Too Many Requests error response. The request has been rejected because the the application has sent too many requests in a given timeframe to the AI assistant service.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Too Many Requests error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Too Many Requests"}
        },
        # Endpoint mulitiple response body examples (overrides the single example)
        examples: %{
          # Identifier for different error cases
          rate_limit: %Example{
            # Error case name
            summary: "Rate limit reached on requests per minute",
            # Error response body example
            value: %{
              error: "Rate limit reached for gpt-4o-mini in organization org-... on requests per min (RPM): Limit 3, Used 3, Requested 1. Please try again in 20s. Visit https://platform.openai.com/account/rate-limits to learn more."
            }
          },
          quota: %Example{
            summary: "Current quota exceeded",
            value: %{
              error: "You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors."
            }
          }
        }
      }
    },
    {502, # Bad Gateway HTTP Error code
      %{
        # Endpoint description
        description: """
          Bad Gateway error response. The application, while acting as a gateway, received an invalid response from the AI assistant server. This may indicate that the AI assistant service is down, misconfigured, or experiencing issues.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Bad Gateway error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Bad Gateway"}
        }
      }
    },
    {504, # Gateway Timeout HTTP Error code
      %{
        # Endpoint description
        description: """
          Gateway Timeout error response. The application, while acting as a gateway, did not receive a timely response from the AI assistant server. This usually happens when the AI assistant service is slow, unresponsive, or experiencing heavy load.
          """,
        # Endpoint response body schema
        schema: %Schema{
          type: :object,
          description: "Gateway Timeout error response.",
          properties: %{
            error: %Schema{
              type: :string,
              description: "Error information detail."
            }
          },
          example: %{error: "Gateway Timeout"}
        }
      }
    }
  }

  # Response builder.
  # If any param (except code) are missig, a default value will be set.
  def build(code), do: build(code, nil, nil, [])

  def build(code, options) when is_list(options) do
    build(code, nil, nil, options)
  end

  def build(code, schema) do
    build(code, nil, schema, [])
  end

  def build(code, schema, options) when is_list(options) do
    build(code, nil, schema, options)
  end

  def build(code, description, schema) do
    build(code, description, schema, [])
  end

  def build(code, description, schema, options) when is_list(options) do
    schema      = schema || @defaults[code][:schema]
    description = description || @defaults[code][:description]
    example     = Keyword.get(options, :example, @defaults[code][:example])
    examples    = Keyword.get(options, :examples, @defaults[code][:examples])
    content =
      case is_nil(examples) do
        true ->
          %{@response_type => %MediaType{schema: schema, example: example}}

        false ->
          %{@response_type => %MediaType{schema: schema, examples: examples}}
      end

    {code, %Response{description: description, content: content}}
  end

  # Indicates the JSON standard view structure
  def view(:standard, schema) do
    %Schema{
      type: :object,
      description: "Request response body.",
      properties: %{data: schema}
    }
  end

  # Indicates the JSON pagination view structure
  def view(:pagination, schema) do
    %Schema{
      type: :object,
      description: "Paginated list request response body.",
      properties: %{
        data: %Schema{
          type: :array,
          items: schema
        },
        meta: %Schema{
          type: :object,
          properties: %{
            count: %Schema{
              type: :integer,
              description: "Number of records in the current page."
            },
            total_count: %Schema{
              type: :integer,
              description: "Total number of records across all pages."
            },
            page: %Schema{
              type: :integer,
              description: "Current page number."
            },
            total_pages: %Schema{
              type: :integer,
              description: "Total number of pages available."
            },
            query: %Schema{
              type: :object,
              description: " Object containing pagination parameters used in the request.",
              properties: %{
                limit: %Schema{
                  type: :integer,
                  description: "Number of records per page."
                },
                offset: %Schema{
                  type: :integer,
                  description: "Starting index for record retrieval."
                },
                field: %Schema{
                  type: :string,
                  description: "Field name used to sort the records."
                },
                order: %Schema{
                  type: :string,
                  format: :enum,
                  enum: [:asc, :desc],
                  description: """
                    Ordering direction used to sort records.

                    **asc:** Ascending order.\n
                    **desc:** Descending order.\n
                    """
                }
              }
            }
          },
          example: %{
            page: 1,
            count: 10,
            total_pages: 42,
            total_count: 417,
            query: %{limit:  10, offset: 0, field: "inserted_at", order: "asc"}
          }
        }
      }
    }
  end
end
