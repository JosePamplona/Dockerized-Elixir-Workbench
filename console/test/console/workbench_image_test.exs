defmodule Console.WorkbenchImageTest do
  use ExUnit.Case, async: true

  alias Console.Workbench

  @conf %{"ELIXIR_VERSION" => "1.19.6", "ERLANG_VERSION" => "28.5.0.6", "PHX_NEW_VERSION" => ""}
  defp never,
    do: fn -> flunk("the daemon was asked, and a stamp or a setting named the installer") end

  test "the workspace's stamp names the installer, over config.conf's setting" do
    assert "dockerized-elixir-workbench:ex1.19.6-erl28.5.0.6-phx1.8.9" =
             Workbench.image_tag(
               %{@conf | "PHX_NEW_VERSION" => "1.8.13"},
               %{"PHX_NEW" => "1.8.9"},
               never()
             )
  end

  test "with no stamp the setting names it, and with neither the daemon's newest for the stack" do
    assert "dockerized-elixir-workbench:ex1.19.6-erl28.5.0.6-phx1.8.13" =
             Workbench.image_tag(%{@conf | "PHX_NEW_VERSION" => "1.8.13"}, nil, never())

    tags = fn ->
      ~w(ex1.19.6-erl28.5.0.6-phx1.8.9 ex1.19.6-erl28.5.0.6-phx1.8.13 ex1.18.4-erl27.3-phx1.9.0)
    end

    assert "dockerized-elixir-workbench:ex1.19.6-erl28.5.0.6-phx1.8.13" =
             Workbench.image_tag(@conf, %{"PHX_NEW" => ""}, tags)
  end

  test "with nothing to name an installer, the tag names none" do
    assert "dockerized-elixir-workbench:ex1.19.6-erl28.5.0.6" =
             Workbench.image_tag(@conf, nil, fn -> [] end)
  end
end
