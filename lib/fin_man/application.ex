defmodule FinMan.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FinManWeb.Telemetry,
      FinMan.Repo,
      {DNSCluster, query: Application.get_env(:fin_man, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FinMan.PubSub},
      # Start a worker by calling: FinMan.Worker.start_link(arg)
      # {FinMan.Worker, arg},
      # Start to serve requests, typically the last entry
      FinManWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FinMan.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FinManWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
