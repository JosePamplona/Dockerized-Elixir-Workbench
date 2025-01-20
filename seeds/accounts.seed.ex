  @doc """
    Retrieves, inserts, or updates the `%User{}` object corresponding to the "sub" claim of a validated token.

    If the user record does not exist, it makes a call to Auth0 and requests 
    the corresponding user profile data, then creates the record.

    If the user record exists and has the email validated, it loads the record 
    from the database.

    If the user record exists but the email is not validated, it makes a call 
    to Auth0 and requests the corresponding user profile data. If the requested 
    data indicates that the email has been verified, the record in the database 
    is updated.

    ## Examples
        iex> token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI..."
        iex> claims = %{
        ...>   "sub" => "auth0|664ad728cddc69d8a11f0368"
        ...> }
        iex> %{elixir_module}.Accounts.user_from_claim(claims, token)
        {:ok, %User{}}

        iex> token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI..."
        iex> claims = %{
        ...>   "sub" => "auth0|inexistent"
        ...> }
        iex> %{elixir_module}.Accounts.user_from_claim(claims, token)
        {:ok, {:error, %{
          code: 401,
          message: "unauthenticated",
          detail: "lorem ipsum"
        }}}
    """
  @spec user_from_claim(claims :: map(), token :: binary()) :: {:ok, User.t()}
  def user_from_claim(claims, token) do
    result =
      claims["sub"]
      |> get_user()
      |> case do
        nil ->
          with \
            {:ok, user_info} <- from_token(token),
            attrs = Map.put(user_info, "token_sub", user_info["sub"]),
            {:ok, user} <- create_user!(attrs)
          do
            user
          end         
          
        %{email_verified: false} = user ->
          with \
            {:ok, attrs} <- from_token(token),
            true         <- attrs["email_verified"],
            {:ok, user} <- update_user!(user, attrs)
          do
            user
          else
            false -> user
          end

        user -> user
      end

    {:ok, result}
  end

  # == Private =================================================================

  defp process_url(path), do: Config.iss() <> path

  defp from_token(token) do
    "userinfo"
    |> process_url()
    |> HTTPoison.get([{"Authorization", "Bearer #{token}"}])
    |> case do
      {:ok, %{status_code: 200} = response} ->
        Config.json_library().decode(response.body)

      {:ok, %{status_code: code, headers: headers, body: body}} ->
        {:error, %{
          code: code,
          message: body,
          detail:
            headers
            |> Enum.find(fn {k, _v} -> k == "WWW-Authenticate" end)
            |> case do
              nil -> nil
              {_, value} -> value
            end
        }}

      {:error, error} ->
        {:error, %{
          code: 500,
          message: "auth service request failed",
          detail: inspect(error)
        }}
    end
  end

  defp get_user(sub), do: Repo.get_by(User, token_sub: sub)

  defp create_user!(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert!()
  end

  defp update_user!(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update!()
  end
