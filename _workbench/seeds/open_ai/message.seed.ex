defmodule %{elixir_module}.Assistant.Message do
  @moduledoc """
  Message identity of `%{elixir_module}.Assistant` context. Represents an individual
  communication unit within a conversation.
  """
  use %{elixir_module}.Schema

  alias %{elixir_module}.Assistant.Conversation

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
