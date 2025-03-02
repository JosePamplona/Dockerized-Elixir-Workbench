defmodule LoremIpsumWeb.Router do
  use LoremIpsumWeb, :router

  alias LoremIpsum.Accounts
  alias Auth0Jwks.Plug.{GetUser, ValidateToken}
  alias OpenApiSpex.Plug.{PutApiSpec, RenderSpec, SwaggerUI}

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LoremIpsumWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :open_api_spec do
    plug PutApiSpec, module: LoremIpsumWeb.OpenApi.Spec
  end

  pipeline :exdoc do
    plug Plug.Static,
      at: "/dev/docs",
      from: {:lorem_ipsum, "priv/static/doc"},
      cache_control_for_etags: "public, max-age=86400",
      gzip: true
  end

  pipeline :auth do
    plug ValidateToken, no_halt: true
    plug GetUser, no_halt: true, user_from_claim: &Accounts.user_from_claim/2
    plug LoremIpsumWeb.Plugs.Token
  end

  scope "/", LoremIpsumWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API REST endpoints scope
  scope "/api/v1", LoremIpsumWeb do
    pipe_through [:api, :auth]

    get "/user", UserController, :get

    get    "/conversation",     ConversationController, :list_conversations
    get    "/conversation/:id", ConversationController, :get_conversation
    post   "/conversation",     ConversationController, :create_conversation
    post   "/conversation/:id", ConversationController, :continue_conversation
    delete "/conversation/:id", ConversationController, :delete_conversation
  end

  # Healthcheck endpoint
  scope "/health", LoremIpsumWeb do
    pipe_through :api

    get "/", HealthcheckController, :health
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lorem_ipsum, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LoremIpsumWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview

      # SwaggerUI interface for REST-API documentation
      get "/swagger", SwaggerUI, path: "/dev/openapi"
    end

    # ExDoc documentation site
    scope "/dev", LoremIpsumWeb do
      pipe_through :exdoc

      get "/docs/",      ExDocController, :index
      get "/docs/cover", ExDocController, :cover
      get "/docs/*path", ExDocController, :handle
    end

    # OpenAPI schema (json file)
    scope "/dev" do
      pipe_through [:api, :open_api_spec]

      get "/openapi", RenderSpec, []
    end
  end
end
