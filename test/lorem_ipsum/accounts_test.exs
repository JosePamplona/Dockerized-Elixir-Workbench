defmodule LoremIpsum.AccountsTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase

  import Mock
  import LoremIpsum.MockHelper
  import LoremIpsum.Fixtures

  alias LoremIpsum.Accounts

  # Get, update or create user on authentication process
  describe "user_from_claim/2" do
    setup [:sessions]

    test "create and retrieve user if it does not exists" do
      sub = "testAuth|0000"
      auth0_user = %{
        sub: sub,
        name: "John Doe",
        email: "john.doe@email.com",
        email_verified: false,
        picture: "http://some.url/user.png"
      }

      with_mocks mocks(:userinfo_response, 200, auth0_user) do
        claims = %{"sub" => auth0_user.sub}

        # Check return
        assert {:ok, user} = Accounts.user_from_claim(claims, "token")
        # Check data were retrieved from the database
        assert user.__meta__.state == :loaded
        # Check user data values
        assert user.token_sub      == auth0_user.sub
        assert user.name           == auth0_user.name
        assert user.email          == auth0_user.email
        assert user.email_verified == auth0_user.email_verified
        assert is_nil(user.phone_number)
        assert URI.to_string(user.picture) == auth0_user.picture
        assert %NaiveDateTime{} = user.inserted_at
        assert %NaiveDateTime{} = user.updated_at
      end
    end

    test "retrieve existing user associated to the `sub` claim", %{
      sessions: %{valid: %{user: session_user}}
    } do
      claims = %{"sub" => session_user.token_sub}
      
      # Check return
      assert {:ok, user} = Accounts.user_from_claim(claims, "token")
      # Check data were retrieved from the database
      assert user.__meta__.state == :loaded
      # Check if is the correct user load
      assert user == session_user
    end

    test "update and retrieve existing user with unverified email when Auth0 user data have changed to verified", %{
      sessions: %{unverified_email: %{user: session_user}}
    } do
      auth0_user = %{
        sub: session_user.token_sub,
        email_verified: true
      }

      with_mocks mocks(:userinfo_response, 200, auth0_user) do
        claims = %{"sub" => session_user.token_sub}
        
        # Check return
        assert {:ok, user} = Accounts.user_from_claim(claims, "token")
        # Check data were retrieved from the database
        assert user.__meta__.state == :loaded
        # Check user previous vs updated state        
        assert user.id           == session_user.id
        assert user.token_sub    == session_user.token_sub
        assert user.name         == session_user.name
        assert user.email        == session_user.email
        assert user.phone_number == session_user.phone_number
        assert user.picture      == session_user.picture
        assert user.inserted_at  == session_user.inserted_at
        assert user.email_verified         == true
        assert session_user.email_verified == false
        assert NaiveDateTime.compare(
          user.updated_at,
          session_user.updated_at
        ) == :gt
      end
    end

    test "do not update and just retrieve existing user with unverified email when Auth0 user data stills unverified", %{
      sessions: %{unverified_email: %{user: session_user}}
    } do
      auth0_user = %{
        sub: session_user.token_sub,
        email_verified: false
      }

      with_mocks mocks(:userinfo_response, 200, auth0_user) do
        claims = %{"sub" => session_user.token_sub}
        
        # Check return
        assert {:ok, user} = Accounts.user_from_claim(claims, "token")
        # Check data were retrieved from the database
        assert user.__meta__.state == :loaded
        # Check if is the correct user load
        assert session_user == user
      end
    end

    test "return error with WWW-Authenticate info" do
      header_content =
        "Bearer realm=\"Users\", error=\"invalid_token\", error_description=\"The access token signature could not be validated. A common cause of this is requesting multiple audiences for an access token signed with HS256, as that signature scheme requires only a single recipient for its security. Please change your API to employ RS256 if you wish to have multiple audiences for your access tokens\""
      headers = [{"WWW-Authenticate", header_content}]
        
      with_mocks mocks(:userinfo_response, 401, "Unauthorized", headers) do
        claims = %{"sub" => "auth|12345"}
        
        # Check return
        assert Accounts.user_from_claim(claims, "token") == {
          :ok,
          {:error, %{
            code: 401,
            detail: header_content,
            message: "Unauthorized"
          }}
        } 
      end
    end

    test "return error without WWW-Authenticate info" do
      with_mocks mocks(:userinfo_response, 400, "Bad request") do
        claims = %{"sub" => "auth|12345"}
        
        # Check return
        assert Accounts.user_from_claim(claims, "token") == {
          :ok,
          {:error, %{
            code: 400,
            detail: nil,
            message: "Bad request"
          }}
        }
      end
    end

    test "return Auth0 request unexpected error" do
      with_mocks [
        {HTTPoison, [:passthrough], get: fn(_, _) -> {:error, :nxdomain} end}
      ] do
        claims = %{"sub" => "auth|12345"}
        
        # Check return
        assert Accounts.user_from_claim(claims, "token") == {
          :ok, 
          {:error, %{
            code: 500,
            detail: ":nxdomain",
            message: "auth service request failed"
          }}
        }
      end
    end
  end
end
