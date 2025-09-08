defmodule GoprintRegistryWeb.Router do
  use GoprintRegistryWeb, :router

  import GoprintRegistryWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GoprintRegistryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :fetch_current_scope_for_api_user
  end

  scope "/", GoprintRegistryWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/pricing", PageController, :pricing
    get "/download", PageController, :download
    get "/docs", PageController, :docs
  end

  # API endpoints for GoPrint registry
  scope "/api", GoprintRegistryWeb do
    pipe_through :api

    # Health check endpoint
    get "/status", RegistryController, :status
    get "/debug/connections", RegistryController, :debug_connections
    
    # Client self-registration endpoints
    post "/clients/register", ClientController, :register
    get "/clients/verify/:client_id", ClientController, :verify
    post "/clients/login", ClientController, :login
    post "/clients/heartbeat", ClientController, :heartbeat
    get "/clients/:client_id/printers", ClientController, :get_printers
    post "/clients/:client_id/test-print", ClientController, :test_print

    # Developer print job endpoints (require authenticated user session)
    post "/print_jobs/file", PrintJobController, :create_file
    post "/print_jobs/test", PrintJobController, :create_test
  end

  ## Authentication routes

  scope "/", GoprintRegistryWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GoprintRegistryWeb.UserAuth, :require_authenticated}],
      layout: {GoprintRegistryWeb.Layouts, :app} do
      live "/dashboard", DashboardLive
      live "/clients", ClientsLive.Index, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/api-keys", UserLive.ApiKeys, :index
    end

    # JSON endpoint for developers to subscribe to a client by id
    post "/clients/subscribe", ClientController, :subscribe

    post "/users/update-password", UserSessionController, :update_password
  end

  ## Admin routes
  scope "/admin", GoprintRegistryWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :require_admin,
      on_mount: [{GoprintRegistryWeb.UserAuth, :require_admin}],
      layout: {GoprintRegistryWeb.Layouts, :app} do
      live "/", DashboardLive
      live "/users", UsersLive
      live "/clients", ClientsLive
    end
  end

  scope "/", GoprintRegistryWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{GoprintRegistryWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Dev routes
  if Application.compile_env(:goprint_registry, :dev_routes) do
    # Enable LiveDashboard and Swoosh mailbox preview in development
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GoprintRegistryWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
