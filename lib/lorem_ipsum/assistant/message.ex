defmodule LoremIpsum.Assistant.Message do
  @moduledoc """
  Message identity of `LoremIpsum.Assistant` context. Represents an individual
  communication unit within a conversation.
  """
  use LoremIpsum.Schema

  alias LoremIpsum.Assistant.Conversation

  defenum RoleEnum, :message_role, [:system, :user, :assistant, :function]

  schema "messages" do
    belongs_to :conversation, Conversation

    field :index,   :integer
    field :role,    RoleEnum
    field :content, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:role, :content])
    |> validate_required([:role, :content])
  end
end
