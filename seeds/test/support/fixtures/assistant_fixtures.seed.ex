defmodule %{elixir_module}.AssistantFixtures do
  @moduledoc """
    This module defines test helpers for creating
    entities via the `%{elixir_module}.Assistant` context.
    """

  import Mock
  import %{elixir_module}.MockHelper

  alias %{elixir_module}.Assistant

  @doc """
    Generate an unique user email.
    """
  def unique_conversation_name, do:
    "Test conversation #{System.unique_integer([:positive])}"

  @doc """
    Generate a user.
    """
  def conversation_fixture(user, attrs \\ %{}) do
    with_mocks mocks(:chat_completion_response) do
      attrs =
        Enum.into(attrs, %{
          name: unique_conversation_name(),
          messages: [
            %{role: "assistant", content: "Assistant message."},
            %{role: "user", content: "User message."}
          ]
        })

      {:ok, conversation} = Assistant.create_conversation(attrs, user)
      conversation
    end
  end
end
