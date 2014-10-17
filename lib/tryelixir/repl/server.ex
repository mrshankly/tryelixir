defmodule Tryelixir.Repl.Config do
  @moduledoc false

  defstruct binding: [],
            cache: '',
            counter: 1,
            env: nil,
            scope: nil

  @type t :: %__MODULE__{}
end

defmodule Tryelixir.Repl.Server do
  @moduledoc false

  use GenServer

  alias Tryelixir.Repl.Config

  @timeout 3000       # Response timeout in miliseconds.
  @afk_timeout 900000 # Inactivity timeout in miliseconds.

  # API

  @spec start_link() :: {:ok, pid} | :ignore | {:error, term}
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  @spec eval(atom, String.t) :: :ok
  def eval(pid, input) do
    GenServer.call(pid, {:eval, input}, @timeout)
  end

  # GenServer callbacks.

  def init([]) do
    env = :elixir.env_for_eval(file: "iex", delegate_locals_to: nil)
    scope = :elixir_env.env_to_scope(env)
    {:ok, %Config{env: env, scope: scope}, @afk_timeout}
  end

  def handle_call({:eval, _input}, _from, config) do
    # TODO
    {:reply, :ok, config, @afk_timeout}
  end

  def handle_call(_msg, _from, config) do
    {:noreply, config, @afk_timeout}
  end

  def handle_info(:timeout, config) do
    {:stop, :normal, config}
  end

  def handle_info(_msg, config) do
    {:noreply, config, @afk_timeout}
  end
end
