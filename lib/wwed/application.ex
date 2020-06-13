defmodule Wwed.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # Wwed.Repo,
      # Start the Telemetry supervisor
      WwedWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Wwed.PubSub},
      # Start the Endpoint (http/https)
      WwedWeb.Endpoint,
      Wwed.GameRegistry,
      Wwed.GameSupervisor,

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wwed.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    WwedWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
