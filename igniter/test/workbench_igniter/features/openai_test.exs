defmodule WorkbenchIgniter.Features.OpenaiTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp installed(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.rest", [])
    |> Igniter.compose_task("workbench.install.enhancements", [])
    |> Igniter.compose_task("workbench.install.auth0", [])
    |> Igniter.compose_task("workbench.install.openai", argv)
    |> apply_igniter!()
    |> Map.get(:assigns)
    |> Map.get(:test_files)
  end

  describe "mix workbench.install.openai" do
    test "creates the assistant context, schemas and ordered migrations" do
      files = installed()

      assert files["lib/test/assistant.ex"] =~ "defmodule Test.Assistant do"
      assert files["lib/test/assistant/conversation.ex"] =~ "Finch.request("
      assert files["lib/test/assistant/message.ex"]

      migrations =
        files
        |> Map.keys()
        |> Enum.filter(&String.match?(&1, ~r|priv/repo/migrations/\d{14}_|))
        |> Enum.sort()

      assert [_users, conversations, messages] = migrations
      assert conversations =~ "create_conversations"
      assert messages =~ "create_messages"
    end

    test "ensures the Finch dependency and pool" do
      files = installed()

      assert files["mix.exs"] =~ ~s|{:finch, "~> 0.18"}|
      assert files["lib/test/application.ex"] =~ "{Finch, [name: Test.Finch]}"
    end

    test "adds the AI_ASSISTANT_* block to runtime.exs" do
      runtime = installed()["config/runtime.exs"]

      assert runtime =~ ~s|System.get_env("AI_ASSISTANT_API_URL")|
      assert runtime =~ "ai_assistant_api_key: ai_assistant_api_key"
    end

    test "rest interface: controller, view, schemas and routes" do
      files = installed()
      router = files["lib/test_web/router.ex"]

      assert files["lib/test_web/controllers/conversation_controller.ex"] =~
               "defmodule TestWeb.ConversationController do"

      assert files["lib/test_web/controllers/conversation_json.ex"]
      assert files["lib/test_web/open_api/schemas/conversation.ex"]
      assert files["lib/test_web/open_api/schemas/message.ex"]

      assert router =~ ~s|get("/conversation", ConversationController, :list_conversations)|

      assert router =~
               ~s|post("/conversation/:id", ConversationController, :continue_conversation)|

      assert router =~
               ~s|delete("/conversation/:id", ConversationController, :delete_conversation)|
    end

    test "plants the unit tests and fixtures" do
      files = installed()

      assert files["test/test/assistant_test.exs"] =~ "defmodule Test.AssistantTest do"

      assert files["test/support/fixtures/assistant_fixtures.ex"] =~
               "defmodule Test.AssistantFixtures do"

      assert files["test/test_web/controllers/conversation_controller_test.exs"]
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.enhancements", [])
      |> Igniter.compose_task("workbench.install.auth0", [])
      |> Igniter.compose_task("workbench.install.openai", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.openai", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "requires auth0" do
    test "refuses, naming it, while auth0 is not in" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.openai", [])

      assert [issue] = igniter.issues
      assert issue =~ "openai builds on auth0"
      assert issue =~ "./wb.sh add auth0"
    end
  end
end
