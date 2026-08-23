defmodule WorkbenchIgniter.Features.Openai do
  @moduledoc """
  OpenAI assistant with the Conversations context. Requires auth0
  (conversations belong to users), so enabling it forces `--auth0` on.

  Full feature cartridge: manifest, install logic and the EEx templates it
  renders live in this directory; the `Mix.Tasks.Workbench.Install.Openai`
  shell in `task.ex` delegates here.

  Ordering: composed after auth0.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.openai --project-name \"Lorem Ipsum\""

  @impl true
  def task, do: "workbench.install.openai"

  @impl true
  def flag, do: :openai

  @impl true
  def implies, do: [:auth0]

  @impl true
  def argv(opts) do
    ["--project-name", opts[:project_name], "--interface", opts[:interface]]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [project_name: :string, interface: :string],
      defaults: [interface: "rest"]
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts =
      Keyword.put_new_lazy(igniter.args.options, :project_name, fn ->
        Mix.Project.config()[:app] |> to_string() |> String.capitalize()
      end)

    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    assistant = Module.concat(app_module, Assistant)

    case Igniter.Project.Module.module_exists(igniter, assistant) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(assistant)} already exists: OpenAI is already installed, skipping."
        )

      {false, igniter} ->
        install(igniter, app_module, opts)
    end
  end

  defp install(igniter, app_module, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    web_dir = web_module |> inspect() |> Macro.underscore()
    app_dir = app_module |> inspect() |> Macro.underscore()

    assigns = [
      app_name: app_name,
      app_module: inspect(app_module),
      web_module: inspect(web_module),
      project_name: opts[:project_name],
      auth0: true
    ]

    dirs = %{app: app_dir, web: web_dir}

    igniter
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"/controllers/")
    |> Igniter.Project.IgniterConfig.dont_move_file_pattern(~r"test/support/fixtures/")
    # The assistant requests go through the application's Finch pool;
    # --no-mailer projects don't have it.
    |> Igniter.Project.Deps.add_dep({:finch, "~> 0.18"}, on_exists: :skip)
    |> Igniter.Project.Application.add_new_child(
      {Finch, {:code, Sourceror.parse_string!("[name: #{inspect(app_module)}.Finch]")}}
    )
    |> configure_runtime(assigns)
    |> create_modules(dirs, assigns)
    |> rest_interface(dirs, web_module, assigns, opts)
    |> create_tests(dirs, assigns, opts)
  end

  defp plant(igniter, template, path, assigns) do
    Igniter.create_new_file(igniter, path, template(template, assigns), on_exists: :overwrite)
  end

  # --- runtime.exs ------------------------------------------------------------

  @runtime_anchor "if config_env() == :prod do"

  defp configure_runtime(igniter, assigns) do
    block = template("runtime.eex", assigns)
    path = "config/runtime.exs"

    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(path, fn source ->
        Rewrite.Source.update(source, :content, &insert_runtime_block(&1, block))
      end)
    else
      Igniter.add_warning(
        igniter,
        "config/runtime.exs not found; please add the AI assistant runtime configuration manually."
      )
    end
  end

  defp insert_runtime_block(content, block) do
    cond do
      String.contains?(content, "AI_ASSISTANT_API_URL") ->
        content

      String.contains?(content, @runtime_anchor) ->
        String.replace(content, @runtime_anchor, block <> @runtime_anchor, global: false)

      true ->
        content <> "\n" <> block
    end
  end

  # --- Modules ----------------------------------------------------------------

  defp create_modules(igniter, dirs, assigns) do
    [conversations_ts, messages_ts] = WorkbenchIgniter.migration_timestamps(igniter, 2)

    igniter
    |> plant("assistant.eex", "lib/#{dirs.app}/assistant.ex", assigns)
    |> plant("conversation.eex", "lib/#{dirs.app}/assistant/conversation.ex", assigns)
    |> plant("message.eex", "lib/#{dirs.app}/assistant/message.ex", assigns)
    |> plant(
      "create_conversations.eex",
      "priv/repo/migrations/#{conversations_ts}_create_conversations.exs",
      assigns
    )
    |> plant(
      "create_messages.eex",
      "priv/repo/migrations/#{messages_ts}_create_messages.exs",
      assigns
    )
  end

  # --- REST interface ---------------------------------------------------------

  defp rest_interface(igniter, dirs, web_module, assigns, opts) do
    if opts[:interface] == "rest" do
      igniter
      |> plant(
        "openapi_conversation.eex",
        "lib/#{dirs.web}/open_api/schemas/conversation.ex",
        assigns
      )
      |> plant("openapi_message.eex", "lib/#{dirs.web}/open_api/schemas/message.ex", assigns)
      |> plant(
        "conversation_json.eex",
        "lib/#{dirs.web}/controllers/conversation_json.ex",
        assigns
      )
      |> plant(
        "conversation_controller.eex",
        "lib/#{dirs.web}/controllers/conversation_controller.ex",
        assigns
      )
      |> Igniter.Libs.Phoenix.append_to_scope(
        "/api/v1",
        """
        get "/conversation", ConversationController, :list_conversations
        get "/conversation/:id", ConversationController, :get_conversation
        post "/conversation", ConversationController, :create_conversation
        post "/conversation/:id", ConversationController, :continue_conversation
        delete "/conversation/:id", ConversationController, :delete_conversation
        """,
        arg2: web_module
      )
    else
      igniter
    end
  end

  # --- Unit tests -------------------------------------------------------------

  defp create_tests(igniter, dirs, assigns, opts) do
    igniter
    |> plant("assistant_test.eex", "test/#{dirs.app}/assistant_test.exs", assigns)
    |> plant("assistant_fixtures.eex", "test/support/fixtures/assistant_fixtures.ex", assigns)
    |> plant_if(
      opts[:interface] == "rest",
      "conversation_controller_test.eex",
      "test/#{dirs.web}/controllers/conversation_controller_test.exs",
      assigns
    )
  end

  defp plant_if(igniter, condition, template, path, assigns) do
    if condition, do: plant(igniter, template, path, assigns), else: igniter
  end
end
