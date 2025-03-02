defmodule LoremIpsum.MockHelper do
  @moduledoc """
  This module defines commonly used mock functions for testing purposes.

  The mock collection includes OpenAI request responses, token validation, and
  user information retrieval from Auth0.
  """

  import Joken

  def mocks(_, default \\ %{})
  def mocks(:authentication, user) do
    [
      {Auth0Jwks.Token, [:passthrough], verify_and_validate: &peek_claims(&1)},
      {LoremIpsum.Accounts, [:passthrough], from_token: fn(_token) -> user end}
    ]
  end

  def mocks(:chat_completion_response, body) do
    body = Enum.into(body, %{
      choices: [
        %{message: %{role: "assistant", content: "Mocked response message."}}
      ]
    })

    [
      {Finch, [:passthrough], request: fn(_request, _client) ->
        {:ok, %{status: 200, body: Jason.encode!(body)}}
      end}
    ]
  end

  def mocks(:chat_completion_response, :error, error) do
    [{Finch, [:passthrough], request: fn(_, _) -> {:error, error} end}]
  end

  def mocks(:chat_completion_response, code, error_message) do
    [
      {Finch, [:passthrough], request: fn(_request, _client) ->
        body = Jason.encode!(%{error: %{message: error_message}})
        {:ok, %{status: code, body: body}}
      end}
    ]
  end

  def mocks(:userinfo_response, code, body, headers \\ []) do
    body = if code == 200, do: Jason.encode!(body), else: body
    response =
      %HTTPoison.Response{status_code: code, headers: headers, body: body}

    [{HTTPoison, [:passthrough], get: fn(_url, _header) -> {:ok, response} end}]
  end
end
