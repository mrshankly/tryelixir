defmodule Tryelixir do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Tryelixir.Repl, []),
      worker(Tryelixir.Watcher, [])
    ]

    opts = [strategy: :one_for_one, name: Tryelixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
