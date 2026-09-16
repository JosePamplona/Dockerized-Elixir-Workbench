defmodule Console.DockerTest do
  use ExUnit.Case, async: true

  alias Console.Docker

  test "ports: docker's two lines per port are one, and exposed-only ports are none" do
    assert ["4001→4000", "5050→5050"] =
             Docker.ports(
               "0.0.0.0:4001->4000/tcp, [::]:4001->4000/tcp, 0.0.0.0:5050->5050/tcp, [::]:5050->5050/tcp"
             )

    assert [] = Docker.ports("5432/tcp")
    assert [] = Docker.ports(nil)
  end

  test "a stats line, with the cursor-home escape the stream puts on the first one" do
    line =
      ~s(\e[H{"BlockIO":"23.5MB / 99.3MB","CPUPerc":"1.12%","Container":"62662f","ID":"62662f","MemPerc":"0.57%","MemUsage":"183.2MiB / 31.28GiB","Name":"some_test-app-1","NetIO":"124MB / 1.84MB","PIDs":"83"})

    assert %{
             name: "some_test-app-1",
             cpu: "1.1 %",
             mem: "183.2 MiB",
             limit: "31.3 GiB",
             memp: "0.57%",
             pids: "83"
           } = Docker.stat(line)

    assert nil == Docker.stat("")
  end

  test "a reading's length does not change between two readings: one unit, one decimal" do
    assert "0.9 MiB" == Docker.mib("952KiB")
    assert "1536.0 MiB" == Docker.mib("1.5GiB")
    # Decimal megabytes are worth less than binary ones: 1.9 MB is 1.8 MiB.
    assert "1.8 MiB" == Docker.mib("1.9MB")
    assert "0.0 MiB" == Docker.mib("0B")
    assert "31.3 GiB" == Docker.gib("31.28GiB")
    # Not 101.35: a half is not a half once it is a float, and either way
    # is one decimal long, which is all the column asks.
    assert "101.4 %" == Docker.percent("101.36%")
    assert "0.0 %" == Docker.percent("0.00%")
    assert "?" == Docker.mib("?")
  end

  test "labels, sizes, and sizes back" do
    assert %{"com.docker.compose.project" => "some_test", "com.docker.compose.service" => "app"} =
             Docker.labels(
               "com.docker.compose.project=some_test,com.docker.compose.service=app,com.docker.compose.depends_on=database:service_healthy:false"
             )

    assert 145_000_000 == Docker.bytes("145MB")
    assert 4_384_000_000 == Docker.bytes("4.384GB")
    assert 736_000 == Docker.bytes("736kB")
    assert "145.0 MB" == Docker.human(145_000_000)
    assert "5.8 GB" == Docker.human(40 * 145_000_000)
  end

  # Six names on one image, read off this machine on 2026-09-05.
  @rows [
    %{
      "ID" => "6a7e63393583",
      "Repository" => "some-test",
      "Tag" => "local",
      "Size" => "570MB",
      "CreatedSince" => "37 hours ago",
      "CreatedAt" => "2026-09-04 00:00:00"
    },
    %{
      "ID" => "6a7e63393583",
      "Repository" => "dew-ex1.20.4-erl29.0.6-phx1.8.13",
      "Tag" => "0.11.0",
      "Size" => "570MB",
      "CreatedSince" => "37 hours ago",
      "CreatedAt" => "2026-09-04 00:00:00"
    },
    %{
      "ID" => "6a7e63393583",
      "Repository" => "awesome-virtus",
      "Tag" => "local",
      "Size" => "570MB",
      "CreatedSince" => "37 hours ago",
      "CreatedAt" => "2026-09-04 00:00:00"
    },
    %{
      "ID" => "e2af995615d0",
      "Repository" => "some-test",
      "Tag" => "0.1.0-prod",
      "Size" => "145MB",
      "CreatedSince" => "17 hours ago",
      "CreatedAt" => "2026-09-05 00:00:00"
    },
    %{
      "ID" => "aaaa00000001",
      "Repository" => "<none>",
      "Tag" => "<none>",
      "Size" => "145MB",
      "CreatedSince" => "17 hours ago",
      "CreatedAt" => "2026-09-05 00:00:00"
    },
    %{
      "ID" => "aaaa00000002",
      "Repository" => "<none>",
      "Tag" => "<none>",
      "Size" => "145MB",
      "CreatedSince" => "17 hours ago",
      "CreatedAt" => "2026-09-05 00:00:00"
    },
    %{
      "ID" => "d662b7dab1a0",
      "Repository" => "yanwk/comfyui-boot",
      "Tag" => "cu130-slim",
      "Size" => "10.6GB",
      "CreatedSince" => "3 months ago",
      "CreatedAt" => "2026-06-01 00:00:00"
    }
  ]

  test "images are grouped by ID, the untagged counted apart, and the scope keeps the house's" do
    %{images: mine, dangling: 2, dangling_size: "290.0 MB"} =
      Docker.group_images(@rows, "some-test", "workspace")

    assert ["e2af995615d0", "6a7e63393583"] = Enum.map(mine, & &1.id)

    assert [
             "awesome-virtus:local",
             "dew-ex1.20.4-erl29.0.6-phx1.8.13:0.11.0",
             "some-test:local"
           ] =
             List.last(mine).names

    %{images: all} = Docker.group_images(@rows, "some-test", "daemon")
    assert ["e2af995615d0", "6a7e63393583", "d662b7dab1a0"] = Enum.map(all, & &1.id)
  end

  test "the composes' secrets are masked, YAML punctuation included" do
    masked =
      Console.Project.mask(
        "    environment:\n      POSTGRES_PASSWORD: postgres\n      POSTGRES_USER: postgres\n      DATABASE_URL: ecto://postgres:postgres@database/app_prod\nSECRET_KEY_BASE=abc"
      )

    assert masked =~ "POSTGRES_PASSWORD: ••••••••"
    assert masked =~ "POSTGRES_USER: postgres"
    assert masked =~ "DATABASE_URL: ecto://postgres:••••@database/app_prod"
    assert masked =~ "SECRET_KEY_BASE=••••••••"
  end
end
