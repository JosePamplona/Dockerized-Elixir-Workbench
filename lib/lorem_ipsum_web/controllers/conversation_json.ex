defmodule LoremIpsumWeb.ConversationJSON do
  @moduledoc """
    JSON Views module for different schema rendering necessities for 
    `LoremIpsum.Assistant.Conversation`.
    """

  alias LoremIpsum.Assistant.Conversation

  @doc """
    Renders a response body containing only the `id` field of a conversation
    schema.

    ## Example
        iex> LoremIpsumWeb.ConversationJSON.id(%{conversation: %Conversation{})
        %{data: %{id: "00000000-0000-4000-8000-000000000000"}}
    """

  @spec id(%{conversation: conversation :: Conversation.t}) :: %{data: map}
  def id(%{conversation: conversation}) do
    %{data: data(:id, conversation)}
  end

  @doc """
    Renders a response body containing a paginated list of conversations and the
    pagination metadata.

    The listed conversations are rendered only with the `id` and `name` fields.

    ## Example
        iex> LoremIpsumWeb.ConversationJSON.index(%{list: paginated_list})
        %{
          data: [
            %{id: "00000000-0000-4000-8000-000000000000", name: "Test 1"}
            %{id: "00000000-0000-4000-8000-000000000001", name: "Test 2"}
            %{id: "00000000-0000-4000-8000-000000000002", name: "Test 3"}
          ],
          meta: %{
            count: 3,
            page: 1,
            total_count: 3,
            total_pages: 1,
            query: {limit: 10, offset: 0, field: "inserted_at", order: "asc"}
          }
        }
    """

  @spec index(%{list: list :: [Conversation.t]}) :: %{data: [map], meta: map}
  def index(%{list: list}) do
    %{
      data: for(record <- list.records, do: data(:index, record)),
      meta: Map.drop(list, [:records])
    }
  end

  @doc """
    Standard conversation render.

    Renders a response body containing all fields of a single conversation
    schema, including all associated messages.

    The messages are rendered only with `role` and `content` fields.

    ## Example
        iex> LoremIpsumWeb.ConversationJSON.show(%{conversation: %Conversation{})
        %{data: %{
          id: "00000000-0000-4000-8000-000000000000",
          name: "Test 1",
          messages: [
            {
              content: "You are a useful assistant.",
              role: "system"
            }
          ],
          inserted_at: %NaiveDateTime{},
          updated_at: %NaiveDateTime{}
        }}
    """

  @spec show(%{conversation: conversation :: Conversation.t}) :: %{data: map}
  def show(%{conversation: conversation}) do
    %{data: data(:show, conversation)}
  end

  @doc """
    Renders a response body containing the last message of a conversation 
    schema only with `role` and `content` fields.

    ## Example
        iex> LoremIpsumWeb.ConversationJSON.last_message(%{conversation: %Conversation{})
        %{data: %{
          content: "You are a useful assistant.",
          role: "system"
        }}
    """

  @spec last_message(%{conversation: conversation :: Conversation.t}) ::
    %{data: map}

  def last_message(%{conversation: conversation}) do
    %{data: data(:last_message, conversation)}
  end

  # --- Private ----------------------------------------------------------------

  defp data(:id, %Conversation{} = conversation), do: %{id: conversation.id}
  defp data(:index, %Conversation{} = conversation) do
    %{
      id: conversation.id,
      name: conversation.name
    }
  end

  defp data(:show, %Conversation{} = conversation) do
    conversation =
      case conversation.messages do
        messages when is_list(messages) -> conversation
        _ -> LoremIpsum.Repo.preload(conversation, :messages)
      end

    %{
      id: conversation.id,
      name: conversation.name,
      messages:
        for(message <- conversation.messages, do: %{
          role: message.role,
          content: message.content
        }),
      inserted_at: conversation.inserted_at,
      updated_at: conversation.updated_at
    }
  end

  defp data(:last_message, %Conversation{} = conversation) do
    last_message = Enum.at(conversation.messages, -1)
    %{
      role: last_message.role,
      content: last_message.content
    }
  end
end
