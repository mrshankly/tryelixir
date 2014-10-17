defmodule Tryelixir.Repl do
  @moduledoc """
  Exposes the REPL API and serves as a supervisor for the different
  `Tryelixir.Repl.Interpreter` processes.
  """

  use Supervisor

  @doc """
  Starts the supervisor.
  """
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a `Tryelixir.Repl.Interpreter` process to the supervisor tree.
  """
  def new() do
    Supervisor.start_child(__MODULE__, [])
  end

  # Supervisor callbacks.

  def init([]) do
    children = [
      worker(Tryelixir.Repl.Server, [],
        restart: :transient,
        shutdown: :brutal_kill)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
