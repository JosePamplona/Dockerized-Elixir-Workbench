defmodule %{elixir_module}Web.ExDocController do
  use %{elixir_module}Web, :controller
  
  def index(conn, _params) do
    redirect(conn, to: ~p"/%{exdoc_endpoint}/index.html") 
  end
  
  <!-- workbench-coveralls open -->
  def cover(conn, _params) do
    redirect(conn, to: ~p"/%{exdoc_endpoint}/excoveralls.html")
  end
  
  <!-- workbench-coveralls close -->
  def not_found(conn, _params) do
    file_path = Path.join(
      :code.priv_dir(:%{project_name}),
      "static/%{resource_dir}/404.html"
    )
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(404, File.read!(file_path))
  end
end
