defmodule Console.WorkbenchImageTest do
  use ExUnit.Case, async: true

  alias Console.Workbench

  @conf %{"ELIXIR_VERSION" => "1.19.6", "ERLANG_VERSION" => "28.5.0.6", "PHX_NEW_VERSION" => ""}
  defp never,
    do: fn -> flunk("the daemon was asked, and a stamp or a setting named the installer") end

  test "the workspace's stamp names the installer, over config.conf's setting" do
    assert "dew-ex1.19.6-erl28.5.0.6-phx1.8.9:0.11.0" =
             Workbench.image_tag(
               %{@conf | "PHX_NEW_VERSION" => "1.8.13"},
               %{"PHX_NEW" => "1.8.9"},
               "0.11.0",
               never()
             )
  end

  test "with no stamp the setting names it, and with neither the daemon's newest for the stack" do
    assert "dew-ex1.19.6-erl28.5.0.6-phx1.8.13:0.11.0" =
             Workbench.image_tag(%{@conf | "PHX_NEW_VERSION" => "1.8.13"}, nil, "0.11.0", never())

    repositories = fn ->
      ~w(dew-ex1.19.6-erl28.5.0.6-phx1.8.9 dew-ex1.19.6-erl28.5.0.6-phx1.8.13 dew-ex1.18.4-erl27.3-phx1.9.0)
    end

    assert "dew-ex1.19.6-erl28.5.0.6-phx1.8.13:0.11.0" =
             Workbench.image_tag(@conf, %{"PHX_NEW" => ""}, "0.11.0", repositories)
  end

  test "with nothing to name an installer, the name carries none" do
    assert "dew-ex1.19.6-erl28.5.0.6:0.11.0" =
             Workbench.image_tag(@conf, nil, "0.11.0", fn -> [] end)
  end

  test "with no version read off wb.sh, the name carries no tag" do
    assert "dew-ex1.19.6-erl28.5.0.6-phx1.8.13" =
             Workbench.image_tag(%{@conf | "PHX_NEW_VERSION" => "1.8.13"}, nil, nil, never())
  end
end
