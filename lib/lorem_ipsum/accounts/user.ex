defmodule LoremIpsum.Accounts.User do
  @moduledoc """
  User from Lib/lorem Ipsum/accounts/ context.
  """
  use LoremIpsum.Schema

  defenum StatusEnum, :user_status, [:active, :blocked]

  schema "users" do
    field :name, :string
    field :status, StatusEnum
    field :email, :string
    field :email_verified, :boolean, default: false
    field :phone_number, :string
    field :picture, EctoURI
    field :token_sub, :string

    timestamps()
  end

  @doc false
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :email_verified,
      :phone_number,
      :picture,
      :token_sub
    ])
    |> validate_required([
      :name,
      :email,
      :email_verified,
      :picture,
      :token_sub
    ])
    |> put_change(:status, "active")
    |> unique_constraint(:token_sub)
    |> unique_constraint(:email)
  end

  @doc false
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email_verified,
      :phone_number,
      :picture
    ])
    |> validate_required([
      :name,
      :email_verified,
      :picture,
    ])
  end
end
