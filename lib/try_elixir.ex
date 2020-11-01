defmodule TryElixir do
  @moduledoc false

  use Application

  def start(_type, _args) do
    port = Application.fetch_env!(:try_elixir, :port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: TryElixir.Router, options: [port: port]}
    ]

    opts = [strategy: :one_for_one, name: TryElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
