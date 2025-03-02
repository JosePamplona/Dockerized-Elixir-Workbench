defmodule %{elixir_module}Web.UserJSON do
  @moduledoc """
    JSON Views module for different schema rendering necessities for 
    `%{elixir_module}.Accounts.User`.
    """

  alias %{elixir_module}.Accounts.User

  @doc """
    Standard user render.

    Renders a response body containing all fields of a single user schema.

    ## Example
        iex> %{elixir_module}Web.UserJSON.show(%{user: %User{})
        %{data: %{
          id: "00000000-0000-4000-8000-000000000000",
          token_sub: "auth0|0123456789abcdef01234567",
          status: "active",
          name: "John Doe",
          email: "john.doe@email.com",
          email_verified: true,
          phone_number: "555-1234",
          picture: %URI{
            scheme: "https",
            authority: "images.com",
            userinfo: nil,
            host: "images.com",
            port: 443,
            path: "/user.png",
            query: nil,
            fragment: nil
          },
          inserted_at: %NaiveDateTime{},
          updated_at: %NaiveDateTime{}
        }}
    """

  @spec show(%{user: user :: User.t}) :: %{data: map}
  def show(%{user: user}) do
    %{data: data(:show, user)}
  end

  # --- Private ----------------------------------------------------------------

  defp data(:show, %User{} = user), do: user
end
