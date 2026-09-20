defmodule WorkbenchIgniter.ServicesConformanceTest do
  @moduledoc """
  The promise every cartridge makes about its own services, checked
  against what it actually answers.

  A cartridge names its containers off its state — ecto's engine,
  db_admin's admins — and `services(:any)` is its promise that *these
  are all of them, whatever you choose*. Two readers stand on that
  promise and neither would notice it broken: `Compose.images/0`, which
  tells the workbench's images from a daemon's by it, and the
  catalog's `offers`, which is the menu the shelf shows before anything
  is picked. Add an engine, forget the `:any` line, and both go quietly
  wrong — the new image stops being the house's, the shelf stops
  offering it, and every test still passes.

  So the promise is checked here, over the real shelf: whatever any one
  choice brings has to be in `:any`.
  """

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Features

  # Every state worth asking a cartridge about, one choice at a time:
  # nothing chosen, and then each value of each option that has any.
  # Not the combinations — a cartridge that needed two choices at once
  # to name a container would be saying its state in a way nothing else
  # in the workbench reads either.
  defp states(feature) do
    info = if feature.pending?(), do: nil, else: feature.info([], nil)
    choices = feature.choices()

    singles =
      for {key, type} <- (info && info.schema) || [],
          value <- values(Keyword.get(choices, key)),
          do:
            {"--#{key} #{value}", if(type == :csv, do: %{key => [value]}, else: %{key => value})}

    [{"nothing chosen", %{}} | singles]
  end

  defp values(nil), do: []
  defp values({:open, values}), do: values(values)

  defp values([{group, grouped} | _] = groups) when is_atom(group) and is_list(grouped),
    do: Enum.flat_map(groups, fn {_, v} -> values(v) end)

  defp values(values), do: Enum.map(values, &value/1)

  defp value({v, _doc, _requires}), do: v
  defp value({v, _doc}), do: v
  defp value(v), do: v

  describe "services(:any)" do
    test "promises every container any one choice brings" do
      for feature <- Features.catalog(),
          promised = feature.services(:any),
          {said, state} <- states(feature),
          name <- feature.services(state) do
        assert name in promised,
               """
               #{feature.name()} brings #{inspect(name)} with #{said}, \
               but services(:any) does not promise it.

               services(:any) says: #{inspect(promised)}

               Add it there. `Compose.images/0` and the catalog's `offers` \
               read that line and nothing else: a container missing from it \
               is a container the workbench does not know is its own.
               """
      end
    end

    test "promises nothing it cannot bring" do
      for feature <- Features.catalog() do
        brought =
          for {_said, state} <- states(feature), name <- feature.services(state), do: name

        for name <- feature.services(:any) do
          assert name in brought,
                 """
                 #{feature.name()} promises #{inspect(name)} in services(:any), \
                 but no single choice brings it.

                 Either a choice for it is missing, or the promise names a \
                 container that is gone.
                 """
        end
      end
    end
  end

  describe "the catalog's offers" do
    test "covers what a project with nothing chosen already gets" do
      for entry <- Enum.map(Features.catalog(), &Features.entry/1) do
        offered = Enum.map(entry.offers, & &1.service)

        for service <- entry.compose do
          assert service.service in offered,
                 "#{entry.name} brings #{service.service} with nothing chosen, " <>
                   "but does not offer it: #{inspect(offered)}"
        end
      end
    end

    test "says the choices each container comes with" do
      offers = fn name ->
        Features.named(name)
        |> Features.entry()
        |> Map.fetch!(:offers)
        |> Map.new(&{&1.service, &1.with})
      end

      # db_admin: one admin per choice, so each waits on its own.
      for admin <- ~w(pgadmin phpmyadmin adminer cloudbeaver),
          do: assert(offers.("db_admin")[admin] == [%{option: :admin, value: admin}])

      # ecto: the server comes with the three engines that have one —
      # sqlite is a file, and brings the one-shot that makes a place
      # for it instead. The migration comes with all four.
      ecto = offers.("ecto")
      assert Enum.map(ecto["database"], & &1.value) == ~w(postgres mysql mssql)
      assert Enum.map(ecto["migrate"], & &1.value) == ~w(postgres mysql mssql sqlite3)
      assert ecto["database_init"] == [%{option: :database, value: "mssql"}]
      assert ecto["volume_init"] == [%{option: :database, value: "sqlite3"}]

      # monitoring takes no options: its two come whatever you do, and
      # `[]` is how the shelf is told not to wait for a switch.
      for service <- ["prometheus", "grafana"],
          do: assert(offers.("monitoring")[service] == [])
    end

    test "leaves out what the choice decides and the service does not" do
      ecto = Features.named("ecto") |> Features.entry() |> Map.fetch!(:offers)
      database = Enum.find(ecto, &(&1.service == "database"))

      # A different repository on a different port per engine: the
      # menu cannot say one, and says none rather than the first.
      assert database.image == nil
      assert database.listens == nil

      # What every engine does agree on, it still says.
      assert "dev" in database.deploys
      assert database.role == "database"
    end
  end
end
