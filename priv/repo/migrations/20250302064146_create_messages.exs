defmodule LoremIpsum.Repo.Migrations.CreateMessages do
  @moduledoc false

  use Ecto.Migration
  alias LoremIpsum.Assistant.Message.RoleEnum
  @table :messages

  def change do
    RoleEnum.create_type()

    create table(@table) do
      add \
        :conversation_id,
        references(:conversations, on_delete: :delete_all),
        null: false
      
      add :index,   :integer,        null: false
      add :role,    RoleEnum.type(), null: false
      add :content, :text,           null: false

      timestamps(default: fragment("NOW()"))
    end

    create index(@table, [:conversation_id])
    create unique_index(@table, [:conversation_id, :index])
    create constraint(@table, :index_positive, check: "index >= 0")
  end
end
