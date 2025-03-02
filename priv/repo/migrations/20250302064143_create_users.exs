defmodule LoremIpsum.Repo.Migrations.CreateUsers do
  @moduledoc false

  use Ecto.Migration
  alias LoremIpsum.Accounts.User.StatusEnum
  @table :users

  def change do
    StatusEnum.create_type()

    create table(@table) do
      add :name,           :string, null: false
      add :status,         StatusEnum.type(), null: false
      add :email,          :string, null: false
      add :email_verified, :boolean, default: false, null: false
      add :phone_number,   :string
      add :picture,        :string
      add :token_sub,      :string, null: false

      timestamps(default: fragment("NOW()"))
    end

    create unique_index(@table, [:token_sub])
    create unique_index(@table, [:email])
  end
end
