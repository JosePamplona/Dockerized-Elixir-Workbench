
  @doc false
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :email_verified,
      :phone_number,
      :picture,
      :token_sub
    ])
    |> validate_required([
      :name,
      :email,
      :email_verified,
      :picture,
      :token_sub
    ])
    |> put_change(:status, "active")
    |> unique_constraint(:token_sub)
    |> unique_constraint(:email)
  end

  @doc false
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email_verified,
      :phone_number,
      :picture
    ])
    |> validate_required([
      :name,
      :email_verified,
      :picture,
    ])
  end
