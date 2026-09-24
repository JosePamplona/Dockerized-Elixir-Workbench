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

    assert %{
             adds: ["ash_oban", "oban_web"],
             args: [],
             tooltip: ["Oban is a background job system" <> _]
           } = site["oban"]

    assert %{
             adds: ["ash_authentication"],
             args: ["--auth-strategy api_key"],
             requires: ["phoenix"]
           } = site["api_key_auth"]

    assert %{tooltip: ["Encrypt & decrypt, changed on the site."]} = site["cloak"]
  end

  test "reads whether the data layers are still independent checkboxes off the command builder" do
    assert Site.data_layers_independent?(
             ~S<v;K.phoenix.checked&&(v="?install=phoenix",K.postgres.checked||(K.sqlite.checked?v+="&with_args=--database%20sqlite3":v+="&with_args=--no-ecto"))>
           )

    refute Site.data_layers_independent?(~S<K.data_layer.value==="postgres">)
  end

  test "compares it with the cartridge, and says what differs" do
    {oks, [], diffs} = @bundle |> Site.parse() |> Site.compare()

    assert "postgres (postgres): as the site" in oks
    assert "oban (ash_oban): as the site" in oks
    assert "api_key_auth (api_key): as the site" in oks

    assert Enum.any?(
             diffs,
             &(&1 =~
                 ~r/^cloak \(ash_cloak\): the site says "Encrypt & decrypt, changed on the site\."/)
           )

    assert Enum.any?(
             diffs,
             &(&1 =~
                 ~r/^appsignal: the site offers it \(adds appsignal, ash_appsignal\), the cartridge does not/)
           )

    refute Enum.any?(oks ++ diffs, &String.starts_with?(&1, "phoenix"))
    refute Enum.any?(oks ++ diffs, &String.starts_with?(&1, "live_view"))
  end

  test "what the site marks coming soon waits, and is no difference" do
    soon =
      String.replace(
        @bundle,
        "<p>Track errors and monitor your application with appsignal.</p>",
        "<p>Track errors. Installer coming soon!</p>"
      )

    {_oks, waiting, diffs} = soon |> Site.parse() |> Site.compare()

    assert [line] = waiting
    assert line =~ "appsignal: the site offers it"
    assert line =~ "coming soon"
    refute Enum.any?(diffs, &(&1 =~ "appsignal"))
  end

  # The home page's widget, one label per feature inside its section, as
  # the site serves it (read 2026-09-24), cut to what the reading needs.
  defp section(title, keys) do
    labels =
      Enum.map_join(
        keys,
        "",
        &~s(<label id="feature-#{&1}" class="feature"><span>#{&1}</span></label>)
      )

    ~s(<div data-category="#{title}" class="feature-category p-2"><h3>#{title}</h3>#{labels}</div></div>)
  end

  # Every section as the site has it today.
  @today [
    {"Web", ~w(phoenix graphql json_api ash_typescript)},
    {"Data Layers", ~w(postgres sqlite csv)},
    {"Authentication", ~w(password_auth magic_link_auth api_key_auth oauth)},
    {"AI", ~w(tidewave ash_ai usage_rules)},
    {"Finance", ~w(money double_entry)},
    {"Automation", ~w(oban state_machine ash_events)},
    {"Safety &amp; Security", ~w(archival paper_trail cloak)},
    {"Dev Tools", ~w(live_debugger admin)},
    {"UI Components", ~w(mishka cinder)}
  ]

  # Each feature's packages, as the bundle's map gives them.
  @map %{
    "phoenix" => %{adds: ["ash_phoenix"], args: []},
    "graphql" => %{adds: ["ash_graphql"], args: []},
    "json_api" => %{adds: ["ash_json_api"], args: []},
    "ash_typescript" => %{adds: ["ash_typescript"], args: ["--framework react"]},
    "postgres" => %{adds: ["ash_postgres"], args: []},
    "sqlite" => %{adds: ["ash_sqlite"], args: []},
    "csv" => %{adds: ["ash_csv"], args: []},
    "password_auth" => %{adds: ["ash_authentication"], args: ["--auth-strategy password"]},
    "magic_link_auth" => %{adds: ["ash_authentication"], args: ["--auth-strategy magic_link"]},
    "api_key_auth" => %{adds: ["ash_authentication"], args: ["--auth-strategy api_key"]},
    "oauth" => %{adds: ["ash_authentication"], args: []},
    "tidewave" => %{adds: ["tidewave"], args: []},
    "ash_ai" => %{adds: ["ash_ai"], args: []},
    "usage_rules" => %{adds: ["usage_rules"], args: []},
    "money" => %{adds: ["ash_money"], args: []},
    "double_entry" => %{adds: ["ash_double_entry"], args: []},
    "oban" => %{adds: ["ash_oban", "oban_web"], args: []},
    "state_machine" => %{adds: ["ash_state_machine"], args: []},
    "ash_events" => %{adds: ["ash_events"], args: []},
    "archival" => %{adds: ["ash_archival"], args: []},
    "paper_trail" => %{adds: ["ash_paper_trail"], args: []},
    "cloak" => %{adds: ["cloak", "ash_cloak"], args: []},
    "live_debugger" => %{adds: ["live_debugger"], args: []},
    "admin" => %{adds: ["ash_admin"], args: []},
    "mishka" => %{adds: ["mishka_chelekom"], args: []},
    "cinder" => %{adds: ["cinder"], args: []}
  }

  defp home(sections), do: Enum.map_join(sections, "\n", fn {t, keys} -> section(t, keys) end)

  test "reads the sections off the home page, each with its features in the page's order" do
    assert Site.sections(home(@today)) |> Enum.take(4) == [
             {"Web", ~w(phoenix graphql json_api ash_typescript)},
             {"Data Layers", ~w(postgres sqlite csv)},
             {"Authentication", ~w(password_auth magic_link_auth api_key_auth oauth)},
             {"AI", ~w(tidewave ash_ai usage_rules)}
           ]

    assert {"Safety & Security", _} =
             List.keyfind(Site.sections(home(@today)), "Safety & Security", 0)
  end

  test "every section as the site has it today: no difference" do
    {oks, diffs} = @today |> home() |> Site.sections() |> Site.compare_sections(@map)

    assert diffs == []
    assert "section «Dev Tools» (--dev-tools): as the site" in oks
    assert "section «Web» (--api): as the site" in oks
    assert "section «Authentication»: oauth2 as the site" in oks
  end

  test "a package the site moved, dropped or added, a section it opened or closed" do
    changed =
      @today
      |> List.keyreplace("Automation", 0, {"Automation", ~w(oban state_machine)})
      |> List.keyreplace(
        "Dev Tools",
        0,
        {"Dev Tools", ~w(live_debugger admin ash_events storybook)}
      )
      |> List.keyreplace("Finance", 0, {"Finance", ~w(money)})
      |> List.keydelete("UI Components", 0)
      |> Kernel.++([{"Observability", ~w(appsignal)}])

    map = Map.put(@map, "storybook", %{adds: ["phoenix_storybook"], args: []})
    {_oks, diffs} = changed |> home() |> Site.sections() |> Site.compare_sections(map)

    assert "section «Automation» (--automation): ash_events moved to «Dev Tools» on the site" in diffs
    assert "section «Finance» (--finance): the site no longer lists ash_double_entry" in diffs

    assert "section «Dev Tools» (--dev-tools): the site added storybook (adds phoenix_storybook), the option does not offer it" in diffs

    assert "section «UI Components» (--components): no longer on the site" in diffs

    assert "section «Observability»: new on the site (appsignal), no option of the cartridge stands for it" in diffs
  end

  test "a strategy the site offers that --auth does not know" do
    map =
      Map.put(@map, "passkey_auth", %{
        adds: ["ash_authentication"],
        args: ["--auth-strategy passkey"]
      })

    sections =
      List.keyreplace(
        @today,
        "Authentication",
        0,
        {"Authentication", ~w(password_auth passkey_auth)}
      )

    {_oks, diffs} = sections |> home() |> Site.sections() |> Site.compare_sections(map)

    assert diffs == [
             "section «Authentication»: the site offers passkey (passkey_auth), --auth does not list it"
           ]
  end
end
