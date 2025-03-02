defmodule LoremIpsumWeb.ConversationController do
  @moduledoc """
    Conversation Operations controller.
    """

  use LoremIpsumWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias LoremIpsum.Assistant
  alias LoremIpsumWeb.{
    ConversationJSON,
    ErrorJSON
  }

  tags ["Conversation Operations"]

  operation :list_conversations,
    summary: "Get the user's conversations list.",
    description: "Retrieve a paginated list of the active session user's conversations with the assistant.",
    security: Requests.security(),
    parameters: Requests.pagination_query_params(),
    responses: [
      Responses.build(
        200,
        "Success retrieving of user's conversations paginated list.",
        Responses.view(
          :pagination,
          Schemas.take_fields(Schemas.Conversation, [:id, :name])
        )
      ),
      Responses.build(401),
      Responses.build(403)
    ]

  @doc """
    Get the user's conversations list.

    Retrieve a paginated list of the active session user's conversations with
    the assistant.
    """

  @spec list_conversations(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def list_conversations(
    %{assigns: %{current_user: current_user}} = conn,
    params
  ) do
    list = Assistant.list_conversations(params, current_user)
    conn
    |> put_status(200)
    |> put_view(json: ConversationJSON)
    |> render(:index, list: list)
  end

  operation :get_conversation,
    summary: "Get a user's single conversation.",
    description: "Retrieve a single conversation with the assistant that belongs to the active session user. This endpoint returns the full messages list.",
    security: Requests.security(),
    required: [:id],
    parameters: [
      id: [
        in: :path,
        description: "Unique identifier of the conversation to retrieve.",
        schema: %Schema{type: :string, format: :uuid},
        example: "00000000-0000-4000-8000-000000000000"
      ]
    ],
    responses: [
      Responses.build(
        200,
        "Success retrieving coversation.",
        Responses.view(:standard, Schemas.Conversation)
      ),
      Responses.build(400, example: %{id: ["is invalid"]}),
      Responses.build(401),
      Responses.build(403),
      Responses.build(404)
    ]

  @doc """
    Get a user's single conversation.

    Retrieve a single conversation with the assistant that belongs to the active
    session user.
    """

  @spec get_conversation(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def get_conversation(
    %{assigns: %{current_user: current_user}} = conn,
    params
  ) do
    params
    |> Assistant.get_conversation(current_user)
    |> case do
      {:ok, conversation}  ->
        conn
        |> put_status(200)
        |> put_view(json: ConversationJSON)
        |> render(:show, conversation: conversation)

      {:error, error} when error in [:not_found, :not_owner] ->
        conn
        |> put_status(404)
        |> put_view(json: ErrorJSON)
        |> render("404.json")

      {:error, changeset}  ->
        conn
        |> put_status(400)
        |> put_view(json: ErrorJSON)
        |> render(:error, changeset: changeset)
    end
  end

  operation :create_conversation,
    summary: "Start a new conversation with the assistant.",
    description: "Initiate a new user's conversation with the assistant by sending the first message(s). The conversation, including the assistant's response, is saved in the database. This endpoint returns the full messages list.",
    security: Requests.security(),
    parameters: Requests.assistant_query_params(),
    request_body: Requests.request_body(
      %Schema{
        type: :object,
        description: "Request body to request create a new conversation",
        required: [:name, :messages],
        properties: %{
          name: %Schema{
            type: :string,
            description: "Provide a name for the conversation in order to identify it, must be unique for each user (max lenght of 255)."
          },
          messages: %Schema{
            description: "In order to start a new conversation, provide at least one message in the array.",
            type: :array,
            items: Schemas.Message.input(:standard)
          }
        },
        example: %{
          name: "Test 1",
          messages: [
            %{
              role: "system",
              content: "You are a useful assistant who preferably responds in Spanish."
            },
            %{role: "user", content: "¡Hola!"}
          ]
        }
      },
      "In order to create a new conversation, you must provide a name for the conversation and the initial message(s) to be sent to the assistant."
    ),
    responses: [
      Responses.build(
        201,
        "Success creating the conversation.",
        Responses.view(:standard, Schemas.Conversation)
      ),
      Responses.build(400, example: %{
        name: [
          "can't be blank",
          "has already been taken"
        ],
        messages: [
          "can't be blank",
          "is invalid",
          "should have at least 1 item(s)",
          %{
            role: [
              "can't be blank",
              "is invalid"
            ],
            content: ["can't be blank"]
          }
        ]
      }),
      Responses.build(401, examples: %{
        user: %{
          summary: "Unauthorized session token",
          value: %{error: "Unauthorized"}
        },
        model: %{
          summary: "Unauthorized AI Assistant API Key",
          value: %{error: "Authentication Fails (no such user)"}
        }
      }),
      Responses.build(403),
      Responses.build(404, example: %{
        error: "The model `invalid-model` does not exist or you do not have access to it."
      }),
      Responses.build(429),
      Responses.build(502),
      Responses.build(504)
    ]

  @doc """
    Start a new conversation with the assistant.

    Initiate a new conversation with the assistant by sending the first
    message(s). The conversation, including the assistant's response, is saved
    in the database. This endpoint returns only the assistant's latest response
    message.
    """

  @spec create_conversation(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def create_conversation(
    %{assigns: %{current_user: current_user}} = conn,
    params
  ) do
    params
    |> Assistant.create_conversation(current_user)
    |> case do
      {:ok, conversation} ->
        conn
        |> put_status(201)
        |> put_view(json: ConversationJSON)
        |> render(:show, conversation: conversation)

      {:error, %{errors: [assistant: {_, keys}]} = _changeset} ->
        conn
        |> put_status(keys[:code])
        |> put_view(json: ErrorJSON)
        |> render(:error, message: keys[:message])

      {:error, %{errors: [connection: {_, keys}]} = _changeset} ->
        conn
        |> put_status(keys[:code])
        |> put_view(json: ErrorJSON)
        |> render("#{keys[:code]}.json")

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> put_view(json: ErrorJSON)
        |> render(:error, changeset: changeset)
    end
  end

  operation :continue_conversation,
    summary: "Send new message(s) within an existing conversation.",
    description: "Continue a specified conversation by adding new message(s) and requesting a response. The updated conversation, including the assistant's response, is saved in the database. This endpoint returns only the assistant's latest response message.",
    security: Requests.security(),
    required: [:id],
    parameters: [
      id: [
        in: :path,
        description: "Unique identifier of the conversation to update.",
        schema: %Schema{type: :string, format: :uuid},
        example: "00000000-0000-4000-8000-000000000000"
      ]
    ] ++ Requests.assistant_query_params(),
    request_body: Requests.request_body(
      %Schema{
        type: :object,
        required: [:name, :messages],
        properties: %{
          messages: %Schema{
            description: "In order to continue a conversation, you must provide at least one message in the array.",
            type: :array,
            items: Schemas.Message.input(:standard)
          }
        },
        example: %{
          messages: [
            %{role: "user", content: "I need something else..."}
          ]
        }
      }
    ),
    responses: [
      Responses.build(
        201,
        "Success continuing the conversation.",
        Responses.view(:standard, Schemas.Message)
      ),
      Responses.build(400, example: %{
        name: [
          "can't be blank",
          "has already been taken"
        ],
        messages: [
          "can't be blank",
          "is invalid",
          "should have at least 1 item(s)",
          %{
            role: [
              "can't be blank",
              "is invalid"
            ],
            content: ["can't be blank"]
          }
        ]
      }),
      Responses.build(401, examples: %{
        user: %{
          summary: "Unauthorized session token",
          value: %{error: "Unauthorized"}
        },
        model: %{
          summary: "Unauthorized AI Assistant API Key",
          value: %{error: "Authentication Fails (no such user)"}
        }
      }),
      Responses.build(403),
      Responses.build(404, examples: %{
        conversation: %{
          summary: "Conversation not found",
          value: %{error: "Not Found"}
        },
        model: %{
          summary: "Model not found",
          value: %{
            error: "The model `invalid-model` does not exist or you do not have access to it."
          }
        }
      }),
      Responses.build(429),
      Responses.build(502),
      Responses.build(504)
    ]

  @doc """
    Send new message(s) within an existing conversation.

    Continue a specified conversation by adding new message(s) and requesting a
    response. The updated conversation, including the assistant's response, is
    saved in the database. This endpoint returns only the assistant's latest
    response message.
    """

  @spec continue_conversation(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def continue_conversation(
    %{assigns: %{current_user: current_user}} = conn,
    params
  ) do
    params
    |> Assistant.continue_conversation(current_user)
    |> case do
      {:ok, conversation}  ->
        conn
        |> put_status(201)
        |> put_view(json: ConversationJSON)
        |> render(:last_message, conversation: conversation)

      {:error, error} when error in [:not_found, :not_owner] ->
        conn
        |> put_status(404)
        |> put_view(json: ErrorJSON)
        |> render("404.json")

      {:error, %{errors: [assistant: {_, keys}]} = _changeset} ->
        conn
        |> put_status(keys[:code])
        |> put_view(json: ErrorJSON)
        |> render(:error, message: keys[:message])

      {:error, %{errors: [connection: {_, keys}]} = _changeset} ->
        conn
        |> put_status(keys[:code])
        |> put_view(json: ErrorJSON)
        |> render("#{keys[:code]}.json")

      {:error, changeset} ->
        conn
        |> put_status(400)
        |> put_view(json: ErrorJSON)
        |> render(:error, changeset: changeset)
    end
  end

  operation :delete_conversation,
    summary: "Delete a user's single conversation.",
    description: "Remove a single conversation with the assistant that belongs to the active session user.",
    security: Requests.security(),
    required: [:id],
    parameters: [
      id: [
        in: :path,
        description: "Unique identifier of the conversation to delete.",
        schema: %Schema{type: :string, format: :uuid},
        example: "00000000-0000-4000-8000-000000000000"
      ]
    ],
    responses: [
      Responses.build(
        200,
        "Success deleting the conversation.",
        Responses.view(
          :standard,
          Schemas.take_fields(Schemas.Conversation, [:id])
        )
      ),
      Responses.build(400, example: %{id: ["is invalid"]}),
      Responses.build(401),
      Responses.build(403),
      Responses.build(404)
    ]

  @doc """
    Delete a user's single conversation.

    Remove a single conversation with the assistant that belongs to the active
    session user.
    """

  @spec delete_conversation(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def delete_conversation(
    %{assigns: %{current_user: current_user}} = conn,
    params
  ) do
    params
    |> Assistant.delete_conversation(current_user)
    |> case do
      {:ok, conversation}  ->
        conn
        |> put_status(200)
        |> put_view(json: ConversationJSON)
        |> render(:id, conversation: conversation)

      {:error, error} when error in [:not_found, :not_owner] ->
        conn
        |> put_status(404)
        |> put_view(json: ErrorJSON)
        |> render("404.json")

      {:error, changeset}  ->
        conn
        |> put_status(400)
        |> put_view(json: ErrorJSON)
        |> render(:error, changeset: changeset)
    end
  end
end
