defmodule Console.ThemesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Console.Themes

  # The suite's shelf (config/test.exs): a probe on each shelf.
  test "two shelves, told apart by the file's suffix, the terminal's first" do
    themes = Themes.all()

    assert [%{key: "probe", kind: :terminal, name: "Probe"}, %{key: "probe", kind: :code}] =
             themes

    assert Enum.all?(themes, &(&1.author == "The suite" and &1.licence == "MIT"))
    assert Enum.all?(themes, &(&1.url == "https://example.test/probe"))
    assert [nil, "The probe's code, as the suite wrote it."] = Enum.map(themes, & &1.about)
  end

  test "a file on no shelf is left out, and said so" do
    dir = Path.join(System.tmp_dir!(), "wb-themes-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.cp!("test/support/themes/probe.terminal.json", Path.join(dir, "probe.terminal.json"))
    File.write!(Path.join(dir, "loose.json"), ~s({"dew.theme": {"name": "Loose"}, "dark": {}}))
    File.write!(Path.join(dir, "bad.code.json"), "{not json")

    {themes, log} = with_log(fn -> Themes.all(dir) end)
    assert [%{key: "probe", kind: :terminal}] = themes
    assert log =~ "loose.json left out"
    assert log =~ "bad.code.json left out"
  end

  test "a shelf is its kind alone, with the file's blocks whole" do
    [terminal] = Themes.shelf(:terminal)
    [code] = Themes.shelf(:code)

    assert terminal.json["dark"]["workbench.colorCustomizations"]["terminal.foreground"] ==
             "#abcdef"

    assert code.json["light"]["workbench.colorCustomizations"]["editor.background"] == "#fefefe"
    assert terminal.json["dew.interface"] == %{"text" => %{"mono" => "fira"}}
  end
end
