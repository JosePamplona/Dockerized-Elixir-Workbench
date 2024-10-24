defmodule %{elixir_module}Web.ExDocController do
  @moduledoc """
    The Accounts context.
    """
  use %{elixir_module}Web, :controller
  
  @priv_dir :code.priv_dir(:%{project_name})
  @resource_dir "/static/%{resource_dir}"
  @exdoc_dir "#{@priv_dir}#{@resource_dir}"

  @doc """
    Creates a Pitcher's account.

    There are two stages in the process.

    - First, all database-related fields are validated against the database.

    - If everything is correct, a call is made to the Stripe API to create a
    new customer and subscribe it to a set of prices. If something goes wrong, 
    all created Stripe elements are deleted, and the database data from the 
    first step is rolled back.

    ## Examples

        iex> create_account(attrs, context)
        {:ok, %User{}}

        iex> create_account(attrs, context)
        {:error, %Ecto.Changeset{}}

    """
  @spec index(conn :: Plug.Conn.t, _params :: map) :: conn :: Plug.Conn.t
  def index(conn, _params) do
    page_path = Path.join(@exdoc_dir, "index.html")
    send_file(conn, 200, page_path)
  end
  
  <!-- workbench-coveralls open -->
  @doc """
    Creates a Pitcher's account.

    There are two stages in the process.

    - First, all database-related fields are validated against the database.

    - If everything is correct, a call is made to the Stripe API to create a
    new customer and subscribe it to a set of prices. If something goes wrong, 
    all created Stripe elements are deleted, and the database data from the 
    first step is rolled back.

    ## Examples

        iex> create_account(attrs, context)
        {:ok, %User{}}

        iex> create_account(attrs, context)
        {:error, %Ecto.Changeset{}}

    """
  @spec cover(conn :: Plug.Conn.t, _params :: map) :: conn :: Plug.Conn.t
  def cover(conn, _params) do
    page_path = Path.join(@exdoc_dir, "excoveralls.html")
    send_file(conn, 200, page_path)
  end
  
  <!-- workbench-coveralls close -->
  @doc """
    Creates a Pitcher's account.

    There are two stages in the process.

    - First, all database-related fields are validated against the database.

    - If everything is correct, a call is made to the Stripe API to create a
    new customer and subscribe it to a set of prices. If something goes wrong, 
    all created Stripe elements are deleted, and the database data from the 
    first step is rolled back.

    ## Examples

        iex> create_account(attrs, context)
        {:ok, %User{}}

        iex> create_account(attrs, context)
        {:error, %Ecto.Changeset{}}

    """
  @spec handle(conn :: Plug.Conn.t, params :: map) :: conn :: Plug.Conn.t
  def handle(conn, %{"path" => path}) do
    page_path = Path.join(@exdoc_dir, path)
    
    case File.exists?(page_path) do
      true  -> send_file(conn, 200, page_path)
      false -> not_found(conn, path)
    end
  end

  # Private --------------------------------------------------------------------

  defp not_found(conn, _params) do
    page_path = Path.join(@exdoc_dir, "404.html")
    send_file(conn, 404, page_path)
  end
end
