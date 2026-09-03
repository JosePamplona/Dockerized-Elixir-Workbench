defmodule ConsoleWeb.Router do
  use ConsoleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ConsoleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ConsoleWeb.Plugs.CSP
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ConsoleWeb do
    pipe_through :browser

    live "/", ConsoleLive
    live "/:tab", ConsoleLive
    get "/covers/*path", CoversController, :show
    get "/figures/*path", FiguresController, :show
    get "/blob/:rev/*path", BlobController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", ConsoleWeb do
  #   pipe_through :api
  # end
end
