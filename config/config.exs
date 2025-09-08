# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :goprint_registry, :scopes,
  user: [
    default: true,
    module: GoprintRegistry.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: GoprintRegistry.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :goprint_registry,
  ecto_repos: [GoprintRegistry.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :goprint_registry, GoprintRegistryWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GoprintRegistryWeb.ErrorHTML, json: GoprintRegistryWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GoprintRegistry.PubSub,
  live_view: [signing_salt: "7uacXk1H"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  goprint_registry: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.14",
  goprint_registry: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Flop
config :flop, repo: GoprintRegistry.Repo

# Configure Ueberauth
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]},
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
