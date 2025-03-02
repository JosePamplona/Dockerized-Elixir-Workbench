defmodule LoremIpsum.EctoURITest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias LoremIpsum.EctoURI

  # EctoURI schema type
  describe "EctoURI type/0" do
    test "success" do
      response = EctoURI.type()

      # Check response
      assert response == :string
    end
  end

  describe "EctoURI cast/1" do
    test "success with string input" do
      input = "http://some.uri/path"
      response = EctoURI.cast(input)

      # Check response 
      assert response == {:ok, %URI{
        scheme: "http",
        authority: "some.uri",
        userinfo: nil,
        host: "some.uri",
        port: 80,
        path: "/path",
        query: nil,
        fragment: nil
      }}
    end

    test "success with URI input" do
      input = %URI{
        scheme: "http",
        authority: "some.uri",
        userinfo: nil,
        host: "some.uri",
        port: 80,
        path: "/path",
        query: nil,
        fragment: nil
      }
      response = EctoURI.cast(input)

      # Check response
      assert response == {:ok, input}
    end

    test "error" do
      input = nil
      response = EctoURI.cast(input)

      # Check response
      assert response == :error
    end
  end

  describe "EctoURI dump/1" do
    test "success" do
      input = %URI{
        scheme: "http",
        authority: "some.uri",
        userinfo: nil,
        host: "some.uri",
        port: 80,
        path: "/path",
        query: nil,
        fragment: nil
      }
      response = EctoURI.dump(input)

      # Check response
      assert response == {:ok, "http://some.uri/path"}
    end

    test "error" do
      input = nil
      response = EctoURI.dump(input)

      # Check response
      assert response == :error
    end
  end
end
