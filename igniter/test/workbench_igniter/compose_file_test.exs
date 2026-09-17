defmodule WorkbenchIgniter.ComposeFileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.ComposeFile
  alias WorkbenchIgniter.ComposeFile.Service

  @golden Path.expand("../fixtures/compose", __DIR__)

  defp pgadmin do
    %Service{
      name: "pgadmin",
      deploys: [:dev, :prod],
      ports: [
        %{
          name: :pgadmin,
          internal: 5050,
          default: 5050,
          comment: ["pgAdmin port.", "Not the database's."]
        }
      ],
      body: "  pgadmin:\n    image: dpage/pgadmin4:latest",
      configs: "  pgadmin_servers:\n    file: ./pgadmin/servers.json"
    }
  end

  defp grafana do
    %Service{
      name: "grafana",
      ports: [%{name: :grafana, internal: 3000, default: 3000, comment: ["Grafana port."]}],
      body: "  grafana:\n    image: grafana/grafana:latest",
      app_waits: [{"grafana", "service_healthy"}],
      configs: "  grafana_datasource:\n    file: ./monitoring/grafana/datasource.yml"
    }
  end

  defp k6, do: %Service{name: "k6", body: "  k6:\n    image: grafana/k6:latest"}

  describe "slots/3" do
    test "gathers what each service contributes, in order, each port under its comment" do
      assert {:ok, slots} =
               ComposeFile.slots([pgadmin(), k6(), grafana()], :dev, %{
                 pgadmin: 5051,
                 grafana: 3000
               })

      assert slots.ports ==
               "      # pgAdmin port.\n      # Not the database's.\n      - 5051:5050\n" <>
                 "      # Grafana port.\n      - 3000:3000"

      assert slots.services ==
               "  pgadmin:\n    image: dpage/pgadmin4:latest\n\n" <>
                 "  k6:\n    image: grafana/k6:latest\n\n" <>
                 "  grafana:\n    image: grafana/grafana:latest"

      assert slots.app_waits == [{"grafana", "service_healthy"}]
      assert slots.volumes == nil

      assert slots.configs ==
               "  pgadmin_servers:\n    file: ./pgadmin/servers.json\n" <>
                 "  grafana_datasource:\n    file: ./monitoring/grafana/datasource.yml"
    end

    test "a service enters only the deployments it names, and asks for no port elsewhere" do
      assert {:ok, slots} = ComposeFile.slots([pgadmin(), grafana()], :scaled, %{grafana: 3001})
      assert slots.ports == "      # Grafana port.\n      - 3001:3000"
      refute slots.services =~ "pgadmin"
    end

    test "a port nobody chose is an error naming its flag" do
      assert {:error, "missing: --port pgadmin=PORT"} =
               ComposeFile.slots([pgadmin(), grafana()], :dev, %{grafana: 3000})
    end
  end

  describe "host_ports/3" do
    test "a port stays where the file has it; a new one is the first free from its default" do
      text =
        "services:\n  pod:\n    ports:\n      - 4001:4000\n      # pgAdmin\n      - 5055:5050\n"

      free = fn default -> default + 1 end

      assert ComposeFile.host_ports([pgadmin(), grafana()], text, free) ==
               %{pgadmin: 5055, grafana: 3001}

      assert ComposeFile.host_ports([pgadmin()], nil, free) == %{pgadmin: 5051}
    end
  end

  describe "reading a baked file" do
    test "services/1 and published/1 off every golden file" do
      for file <- File.ls!(@golden), String.ends_with?(file, ".yml") do
        text = File.read!(Path.join(@golden, file))
        services = ComposeFile.services(text)
        assert services != [], file

        for {service, pairs} <- ComposeFile.published(text) do
          assert service in services, file
          assert Enum.all?(pairs, fn {host, inside} -> host > 0 and inside > 0 end), file
        end
      end
    end

    test "the pod publishes for everyone, a comment between two ports ends nothing" do
      text = """
      services:
        pod:
          image: registry.k8s.io/pause:3.10
          ports:
            # Application port (host:container).
            - 4001:4000
            # pgAdmin port.
            - 5050:5050

        app:
          image: x:local
          healthcheck:
            test: ["CMD", "bash"]
      volumes:
        build:
      """

      assert ComposeFile.services(text) == ~w(pod app)
      assert ComposeFile.published(text) == %{"pod" => [{4001, 4000}, {5050, 5050}]}
      assert ComposeFile.host_port(text, 4000) == 4001
      assert ComposeFile.host_port(text, 3000) == nil
    end
  end
end
