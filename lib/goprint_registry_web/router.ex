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
  end

  scope "/", GoprintRegistryWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/pricing", PageController, :pricing
    get "/download", PageController, :download
  end

  # API endpoints for GoPrint registry
  scope "/api", GoprintRegistryWeb do
    pipe_through :api

    # Registry endpoints (backward compatibility)
    post "/register", RegistryController, :register
    get "/lookup/:api_key", RegistryController, :lookup
    get "/status", RegistryController, :status
    
    # Print job endpoints
    post "/print", PrintController, :print
    post "/print/bulk", PrintController, :bulk_print
    get "/jobs", PrintController, :list_jobs
    get "/jobs/:job_id", PrintController, :job_status
    get "/clients", PrintController, :list_clients
  end

  ## Authentication routes

  scope "/", GoprintRegistryWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GoprintRegistryWeb.UserAuth, :require_authenticated}] do
      live "/dashboard", DashboardLive
      live "/clients", ClientsLive.Index, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
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
