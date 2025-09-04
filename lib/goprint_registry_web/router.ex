defmodule GoprintRegistryWeb.Router do
  use GoprintRegistryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GoprintRegistryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GoprintRegistryWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API endpoints for GoPrint registry
  scope "/api", GoprintRegistryWeb do
    pipe_through :api

    post "/register", RegistryController, :register
    get "/lookup/:api_key", RegistryController, :lookup
    get "/status", RegistryController, :status
  end
end
