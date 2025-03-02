defmodule %{elixir_module}Web.ExDocController do
  @moduledoc """
    ExDoc documentation pages controller.
    """

  use %{elixir_module}Web, :controller

  @priv_dir :code.priv_dir(:%{project_name})
  @resource_dir "/static/%{resource_dir}"
  @exdoc_dir "#{@priv_dir}#{@resource_dir}"

  @doc """
    For a request with no specified page, sends the index page.
    """

  @spec index(conn :: Plug.Conn.t, _params :: map) :: conn :: Plug.Conn.t
  def index(conn, _params) do
    page_path = Path.join(@exdoc_dir, "index.html")
    send_file(conn, 200, page_path)
  end

  # <!-- workbench-coveralls open -->
  @doc """
    For a request specifiying coverage, sends the coverage report page.
    """

  @spec cover(conn :: Plug.Conn.t, _params :: map) :: conn :: Plug.Conn.t
  def cover(conn, _params) do
    page_path = Path.join(@exdoc_dir, "excoveralls.html")
    send_file(conn, 200, page_path)
  end

  # <!-- workbench-coveralls close -->
  @doc """
    If the requested specific page does not exists, sends the not-found error
    page.
    """

  @spec handle(conn :: Plug.Conn.t, _params :: map) :: conn :: Plug.Conn.t
  def handle(conn, _params) do
    page_path = Path.join(@exdoc_dir, "404.html")
    send_file(conn, 404, page_path)
  end
end
