defmodule Console.HighlightSampleTest do
  use ExUnit.Case, async: true

  alias Console.Highlight

  test "the sample touches every rule of the palette" do
    html = Highlight.sample()

    for class <- ~w(k nc na kn s ss mi nf o sr p c1) do
      assert html =~ ~s(class="#{class}"), "no #{class} in the sample"
    end
  end
end
