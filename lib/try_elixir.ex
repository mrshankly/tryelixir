defmodule TryElixir do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: TryElixir.Router, options: [port: 8080]}
    ]

    opts = [strategy: :one_for_one, name: TryElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
