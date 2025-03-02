defmodule LoremIpsum.AssistantTest do
  @moduledoc false

  use LoremIpsum.DataCase

  import Mock
  import LoremIpsum.MockHelper
  import LoremIpsum.AssistantFixtures
  import LoremIpsum.Fixtures

  alias LoremIpsum.Assistant
  alias LoremIpsum.Assistant.Conversation

  setup [:sessions]

  @invalid_id    "invalid-uuid"
  @inexistent_id "00000000-0000-0000-0000-000000000000"

  # Get the user's conversations list.
  describe "list_conversations/2" do
    test "list conversations when there are associated to the user", %{
      sessions: %{valid: %{user: session_user}}
    } do
      conversation_01 = conversation_fixture(session_user)
      conversation_02 = conversation_fixture(session_user)
      conversation_03 = conversation_fixture(session_user)

      result = Assistant.list_conversations(%{}, session_user)

      # Check return
      assert %{
        records: [
          %Conversation{} = record_01,
          %Conversation{} = record_02,
          %Conversation{} = record_03
        ],
        count: 3,
        page: 1,
        total_count: 3,
        total_pages: 1,
        query: %{offset: 0, limit: 15, field: :inserted_at, order: :asc}
      } = result
      # Check records retrieval are correct
      assert record_01.id      == conversation_01.id
      assert record_02.id      == conversation_02.id
      assert record_03.id      == conversation_03.id
      assert record_01.user_id == session_user.id
      assert record_02.user_id == session_user.id
      assert record_03.user_id == session_user.id
    end

    test "empty conversations list when none are associated to the user", %{
      sessions: %{valid: %{user: session_user}}
    } do
      result = Assistant.list_conversations(%{}, session_user)

      # Check return
      assert %{
        records: [],
        count: 0,
        page: 1,
        total_count: 0,
        total_pages: 0,
        query: %{offset: 0, limit: 15, field: :inserted_at, order: :asc}
      } = result
    end

    test "do not list conversations from different users", %{
      sessions: %{
        valid: %{user: session_user},
        not_owner: %{user: other_user}
      }
    } do
      conversation_01 = conversation_fixture(session_user)
      _conversation_02 = conversation_fixture(other_user)

      result = Assistant.list_conversations(%{}, session_user)

      # Check return
      assert %{
        records: [
          %Conversation{} = record_01
        ],
        count: 1,
        page: 1,
        total_count: 1,
        total_pages: 1,
        query: %{offset: 0, limit: 15, field: :inserted_at, order: :asc}
      } = result
      # Check records retrieval are correct
      assert record_01.id      == conversation_01.id
      assert record_01.user_id == session_user.id
    end
  end

  # Get a user's single conversation.
  describe "get_conversation/2" do
    setup [:conversations]

    test "get conversation when is associated to the user", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      attrs = %{"id" => conversation.id}
      result = Assistant.get_conversation(attrs, session_user)

      # Check return
      assert {:ok, %Conversation{} = entity} = result
      # Check records retrieval are correct
      assert entity.id      == conversation.id
      assert entity.user_id == session_user.id
    end

    test "error when id is not a valid uuid", %{
      sessions: %{valid: %{user: session_user}}
    } do
      attrs = %{id: @invalid_id}
      result = Assistant.get_conversation(attrs, session_user)

      # Check return
      assert {:error, %Ecto.Changeset{} = changeset} = result
      assert errors_on(changeset) == %{id: ["is invalid"]}
    end

    test "error when conversation does not exists", %{
      sessions: %{valid: %{user: session_user}}
    } do
      attrs = %{id: @inexistent_id}
      result = Assistant.get_conversation(attrs, session_user)

      # Check return
      assert result == {:error, :not_found}
    end

    test "error when conversation does not belongs to the user", %{
      sessions: %{
        valid: %{user: session_user},
        not_owner: %{user: other_user}
      }
    } do
      conversation = conversation_fixture(other_user)
      attrs = %{id: conversation.id}
      result = Assistant.get_conversation(attrs, session_user)

      # Check return
      assert result == {:error, :not_owner}
    end
  end

  # Start a new conversation with the assistant.
  describe "create_conversation/2" do
    @valid_attrs %{
      "name" => "Test",
      "messages" => [
        %{"role" => "assistant", "content" => "Assistant message."},
        %{"role" => "user",      "content" => "User message."}
      ]
    }

    test "create a new conversation associated to the user", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        result = Assistant.create_conversation(@valid_attrs, session_user)

        # Check return
        assert {:ok, %Conversation{} = entity} = result
        assert entity.user_id == session_user.id
        assert entity.name == @valid_attrs["name"]
      end
    end

    test "handle valid \'temperature\' on query parameters", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "temperature", "0.7")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{}} = result
      end
    end

    test "handle min \'temperature\' on query parameters", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "temperature", "-1")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{}} = result
      end
    end

    test "handle max \'temperature\' on query parameters", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "temperature", "2")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{}} = result
      end
    end

    test "handle valid \'max_tokens\' on query parameters", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "max_tokens", "32")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{}} = result
      end
    end

    test "handle min \'max_tokens\' on query parameters", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "max_tokens", "-1")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{}} = result
      end
    end

    test "error when invalid conversation field types are given", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{
          "name" => false,
          "messages" => false
        }
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          name: ["is invalid"],
          messages: ["is invalid"]
        }
      end
    end

    test "error when required conversation fields are missing", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{}
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          name: ["can't be blank"],
          messages: ["can't be blank"]
        }
      end
    end

    test "error when invalid message field types are given", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(
          @valid_attrs,
          "messages",
          [%{"role" => false, "content" => false}]
        )
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            %{role: ["is invalid"], content: ["is invalid"]}
          ]
        }
      end
    end

    test "error when required message fields are missing", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "messages", [%{}])
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            %{role: ["can't be blank"], content: ["can't be blank"]}
          ]
        }
      end
    end

    test "error when conversation name is already taken", %{
      sessions: %{valid: %{user: session_user}}
    } do
      conversation = conversation_fixture(session_user)

      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "name", conversation.name)
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          name: ["has already been taken"]
        }
      end
    end

    test "error when conversation messages are less than one", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "messages", [])
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            "should have at least 1 item(s)",
            "can't be blank"
          ]
        }
      end
    end

    test "error responses on AI assistant HTTP requests", %{
      sessions: %{valid: %{user: session_user}}
    } do
      error_message = """
      The model 'invalid-model' does not exist or you do not have access to it.
      """

      with_mocks mocks(:chat_completion_response, 404, error_message) do
        attrs = Map.put(@valid_attrs, "model", "invalid-model")
        result = Assistant.create_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [assistant: {"", code: 404, message: error_message}]
      end
    end

    test "error on AI assistant HTTP requests", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response, :error, :nxdomain) do
        result = Assistant.create_conversation(@valid_attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [connection: {"", code: 502}]
      end
    end

    test "error on AI assistant HTTP requests timeout", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response, :error, :timeout) do
        result = Assistant.create_conversation(@valid_attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [connection: {"", code: 504}]
      end
    end
  end

  # Send new message(s) within an existing conversation.
  describe "continue_conversation/2" do
    @valid_attrs %{
      "messages" => [
        %{"role" => "user", "content" => "User continuing message."}
      ]
    }

    setup [:conversations]

    test "continue an existing conversation associated to the user", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "id", conversation.id)
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{} = entity} = result
        assert entity.user_id == session_user.id
      end
    end

    test "error when conversation does not exists", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = Map.put(@valid_attrs, "id", @inexistent_id)
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert result == {:error, :not_found}
      end
    end

    test "error when conversation does not belongs to the user", %{
      sessions: %{
        valid: %{user: session_user},
        not_owner: %{user: other_user}
      }
    } do
      conversation = conversation_fixture(other_user)
      
      with_mocks mocks(:chat_completion_response) do
        attrs = %{"id" => conversation.id}
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert result == {:error, :not_owner}
      end
    end

    test "error when id is not a valid uuid", %{
      sessions: %{valid: %{user: session_user}}
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{"id" => @invalid_id}
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{id: ["is invalid"]}
      end
    end

    test "error when invalid conversation field types are given", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{
          "id" => conversation.id,
          "messages" => false
        }
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{messages: ["is invalid"]}
      end
    end

    test "error when invalid message field types are given", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{
          "id" => conversation.id,
          "messages" => [
            %{"role" => false, "content" => false}
          ]
        }
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            %{role: ["is invalid"], content: ["is invalid"]}
          ]
        }
      end
    end

    test "error when required conversation fields are missing", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{"id" => conversation.id}
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{messages: ["can't be blank"]}
      end
    end

    test "error when required message fields are missing", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{
          "id" => conversation.id,
          "messages" => [%{}]
        }
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            %{role: ["can't be blank"], content: ["can't be blank"]}
          ]
        }
      end
    end

    test "error when new messages are less than one", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{
          "id" => conversation.id,
          "messages" => []
        }
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{} = changeset} = result
        assert errors_on(changeset) == %{
          messages: [
            "should have at least 1 item(s)",
            "can't be blank"
          ]
        }
      end
    end

    test "error response on assistant HTTP requests", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      error_message = "The model \'invalid-model\' does not exist or you do not have access to it."

      with_mocks mocks(:chat_completion_response, 404, error_message) do
        attrs =
          @valid_attrs
          |> Map.put("id", conversation.id)
          |> Map.put("model", "invalid-model")
        
        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [assistant: {"", code: 404, message: error_message}]
      end
    end

    test "error on AI assistant HTTP requests", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response, :error, :nxdomain) do
        attrs = Map.put(@valid_attrs, "id", conversation.id)

        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [connection: {"", code: 502}]
      end
    end

    test "error on AI assistant HTTP requests timeout", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response, :error, :timeout) do
        attrs = Map.put(@valid_attrs, "id", conversation.id)

        result = Assistant.continue_conversation(attrs, session_user)

        # Check return
        assert {:error, %Ecto.Changeset{errors: errors}} = result
        assert errors == [connection: {"", code: 504}]
      end
    end
  end

  # Delete a user's single conversation.
  describe "delete_conversation/2" do

    setup [:conversations]

    test "delete an existing conversation associated to the user", %{
      sessions: %{valid: %{user: session_user}},
      conversations: %{
        conversation_01: conversation
      }
    } do
      with_mocks mocks(:chat_completion_response) do
        attrs = %{"id" => conversation.id}
        result = Assistant.delete_conversation(attrs, session_user)

        # Check return
        assert {:ok, %Conversation{} = entity} = result
        assert entity.id == conversation.id
      end
    end

    test "error when conversation does not exists", %{
      sessions: %{valid: %{user: session_user}}
    } do
      attrs = %{"id" => @inexistent_id}
      result = Assistant.delete_conversation(attrs, session_user)

      # Check return
      assert result == {:error, :not_found}
    end

    test "error when conversation does not belongs to the user", %{
      sessions: %{
        valid: %{user: session_user},
        not_owner: %{user: other_user}
      }
    } do
      conversation = conversation_fixture(other_user)
      attrs = %{"id" => conversation.id}
      result = Assistant.delete_conversation(attrs, session_user)

      # Check return
      assert result == {:error, :not_owner}
    end

    test "error when id is not a valid uuid", %{
      sessions: %{valid: %{user: session_user}}
    } do
      attrs = %{"id" => @invalid_id}
      result = Assistant.delete_conversation(attrs, session_user)

      # Check return
      assert {:error, %Ecto.Changeset{} = changeset} = result
      assert errors_on(changeset) == %{id: ["is invalid"]}
    end
  end
end
