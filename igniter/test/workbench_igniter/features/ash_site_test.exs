defmodule WorkbenchIgniter.Features.Ash.SiteTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Features.Ash.Site

  # A slice of the site's feature map as its bundle carries it (read
  # 2026-08-29), with one entry changed to see the comparison notice it.
  @bundle ~S"""
  Tr={postgres:{tooltip:`     <p class="mb-2">     PostgreSQL     </p>     <p>     The swiss army knife of databases. Versatile, powerful, and battle-tested.     </p>     `,features:["postgres"]},foo={},Wr={postgres:{adds:["ash_postgres"],order:1,links:[{link:"https://hexdocs.pm/ash_postgres",name:"AshPostgres"}],tooltip:`     <p class="mb-2">     The swiss army knife of databases. Versatile, powerful, and battle-tested.     </p>     `},phoenix:{adds:["ash_phoenix"],tooltip:`<p>Ash works seamlessly with Phoenix.</p>`},api_key_auth:{requires:["phoenix"],adds:["ash_authentication"],order:8,args:["--auth-strategy api_key"],tooltip:`     <p class="mb-2">     Generate and authenticate with API keys.     </p>     `},oban:{adds:["ash_oban","oban_web"],order:11,tooltip:`     <p class="mb-2">     Oban is a background job system backed by your own SQL database packed with enterprise grade features, real-time monitoring with Oban Web, and complex workflow management with Oban Pro.     </p>     `},cloak:{adds:["cloak","ash_cloak"],order:18,tooltip:`     <p class="mb-2">     Encrypt &amp; decrypt, changed on the site.     </p>     `},appsignal:{adds:["appsignal","ash_appsignal"],tooltip:`<p>Track errors and monitor your application with appsignal.</p>`},live_view:{tooltip:`<p>Full stack Elixir!</p>`,features:["phoenix"]}},ei="new-proj"
  """

  test "parses the feature map: packages, args, tooltip paragraphs" do
    site = Site.parse(@bundle)

    assert %{adds: ["ash_oban", "oban_web"], args: [], tooltip: ["Oban is a background job system" <> _]} = site["oban"]
    assert %{adds: ["ash_authentication"], args: ["--auth-strategy api_key"], requires: ["phoenix"]} = site["api_key_auth"]
    assert %{tooltip: ["Encrypt & decrypt, changed on the site."]} = site["cloak"]
  end

  test "reads whether the data layers are still independent checkboxes off the command builder" do
    assert Site.data_layers_independent?(~S<v;K.phoenix.checked&&(v="?install=phoenix",K.postgres.checked||(K.sqlite.checked?v+="&with_args=--database%20sqlite3":v+="&with_args=--no-ecto"))>)
    refute Site.data_layers_independent?(~S<K.data_layer.value==="postgres">)
  end

  test "compares it with the cartridge, and says what differs" do
    {oks, diffs} = @bundle |> Site.parse() |> Site.compare()

    assert "postgres (postgres): as the site" in oks
    assert "oban (ash_oban): as the site" in oks
    assert "api_key_auth (api_key): as the site" in oks
    assert Enum.any?(diffs, &(&1 =~ ~r/^cloak \(ash_cloak\): the site says "Encrypt & decrypt, changed on the site\."/))
    assert Enum.any?(diffs, &(&1 =~ ~r/^appsignal: the site offers it \(adds appsignal, ash_appsignal\), the cartridge does not/))
    refute Enum.any?(oks ++ diffs, &String.starts_with?(&1, "phoenix"))
    refute Enum.any?(oks ++ diffs, &String.starts_with?(&1, "live_view"))
  end
end
