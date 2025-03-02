defmodule LoremIpsumWeb.HealthcheckControllerTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase

  import Mock

  # == Health-check ============================================================
  describe "[REST] /health" do
    alias LoremIpsum.Repo

    test "return 200 in prod", %{conn: conn} do
      # Simulates beign in production enviroment
      Application.put_env(:lorem_ipsum, :dev_routes, nil)

      response =
        conn
        |> get(~p"/health")
        |> json_response(200)

      # Check response
      assert response == %{"health" => "😊"}
      
      # Application variables changes rollback
      Application.put_env(:lorem_ipsum, :dev_routes, true)
    end

    test "return 200 with app information in dev", %{conn: conn} do
      response =
        conn
        |> get(~p"/health")
        |> json_response(200)

      # Check response
      assert response == %{
        "app" => %{
          "env" => "test",
          "elixir"  => nil,
          "erlang"  => nil,
          "service" => "#{Mix.Project.config[:app]}",
          "version" => "#{Mix.Project.config[:version]}",
          "time"    => nil
        },
        "databases" => [
          %{
            "repo"    => "Elixir.LoremIpsum.Repo",
            "version" => nil,
            "time"    => nil
          }
        ]
      }
    end

    test "return 200 with extended information in dev", %{conn: conn} do
      response =
        conn
        |> get(~p"/health?verbose=true")
        |> json_response(200)

      # Check response
      assert %{
        "app" => %{
          "env"     => "test",
          "elixir"  => elixir,
          "erlang"  => erlang,
          "service" => service,
          "version" => version,
          "time"    => _
        },
        "databases" => [
          %{
            "repo"    => "Elixir.LoremIpsum.Repo",
            "version" => db_version,
            "time"    => _
          }
        ]
      } = response

      # Check fields data
      assert elixir     =~ "Elixir"
      assert erlang     =~ "Erlang/OTP"
      assert db_version =~ "PostgreSQL"
      assert service    == "#{Mix.Project.config[:app]}"
      assert version    == "#{Mix.Project.config[:version]}"
    end

    test "return 200 handling information ecto errors", %{conn: conn} do
      with_mock Repo, [:passthrough], query:
        fn(_) -> raise Postgrex.Error end
      do
        response =
          conn
          |> get(~p"/health?verbose=true")
          |> json_response(200)

        # Check response
        assert %{
          "databases" => [
            %{
              "repo" => "Elixir.LoremIpsum.Repo",
              "time" => "",
              "version" => "%Postgrex.Error" <> _rest
            }
          ]
        } = response
      end
    end

    test "return 200 handling information system errors", %{conn: conn} do
      with_mock System, [:passthrough], cmd:
        fn(_, _) -> raise RuntimeError end
      do
        response =
          conn
          |> get(~p"/health?verbose=true")
          |> json_response(200)

        # Check response
        assert %{
          "app" => %{"elixir" => "%RuntimeError" <> _rest}
        } = response
      end
    end
  end
end
