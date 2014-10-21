defmodule Tryelixir.Repl.Config do
  @moduledoc false

  defstruct binding: [],
            cache: '',
            counter: 1,
            env: nil,
            scope: nil,
            mod_locals: []

  @type t :: %__MODULE__{}
end

defmodule Tryelixir.Repl.Server do
  @moduledoc false

  use GenServer

  alias Tryelixir.Repl.Config
  alias Tryelixir.Repl.Sandbox

  @timeout 3000       # Response timeout in miliseconds.
  @afk_timeout 900000 # Inactivity timeout in miliseconds.

  @imports '''
  import Tryelixir.Repl.Locals
  import Kernel, except: [spawn: 1, spawn: 3]
  '''

  # API

  @spec start_link() :: {:ok, pid} | :ignore | {:error, term}
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  @spec eval(atom, String.t) :: Sandbox.result
  def eval(pid, input) do
    GenServer.call(pid, {:eval, input}, @timeout)
  end

  # GenServer callbacks.

  def init([]) do
    Tryelixir.Watcher.add(self())
    env = :elixir.env_for_eval(file: "iex", delegate_locals_to: nil)
    {_, _, env, scope} = :elixir.eval(@imports, [], env)
    {:ok, %Config{env: env, scope: scope}, @afk_timeout}
  end

  def handle_call({:eval, input}, _from, config) do
    {result, new_config} = Sandbox.eval(input, config)
    {:reply, result, new_config, @afk_timeout}
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

  def terminate(_reason, _config) do
    Tryelixir.Watcher.remove(self())
  end
end
