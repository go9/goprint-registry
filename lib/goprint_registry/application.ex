defmodule GoprintRegistry.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GoprintRegistryWeb.Telemetry,
      GoprintRegistry.Repo,
      {DNSCluster, query: Application.get_env(:goprint_registry, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GoprintRegistry.PubSub},
      # Start the registry GenServer for managing GoPrint services
      GoprintRegistry.Registry,
      # Start connection manager for desktop clients
      GoprintRegistry.ConnectionManager,
      # Start job queue for print jobs
      GoprintRegistry.JobQueue,
      # Start to serve requests, typically the last entry
      GoprintRegistryWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GoprintRegistry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GoprintRegistryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
