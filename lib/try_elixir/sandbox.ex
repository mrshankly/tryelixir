defmodule TryElixir.Sandbox do
  @moduledoc """
  A sandboxed elixir interpreter.
  """

  use GenServer

  @eval_timeout 3_000
  @init_timeout 30_000
  @idle_timeout 300_000

  @spec start :: {:ok, pid} | {:error, any}
  def start do
    GenServer.start(__MODULE__, [])
  end

  @spec start_link :: {:ok, pid} | {:error, any}
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  @spec eval(pid, String.t()) :: any
  def eval(pid, code) do
    GenServer.call(pid, {:input, code}, @eval_timeout)
  end

  @impl GenServer
  def init([]) do
    env = :elixir.env_for_eval(file: "iex", line: 1, delegate_locals_to: nil)
    {:ok, %{binding: [], cache: '', counter: 1, env: env}, @init_timeout}
  end

  @impl GenServer
  def handle_call({:input, input}, _from, state) do
    {new_state, result} =
      try do
        code = state.cache ++ String.to_charlist(input)
        quoted = Code.string_to_quoted(code, file: "iex", line: state.counter)
        eval(quoted, code, state)
      rescue
        exception ->
          new_state = %{state | cache: '', counter: state.counter + 1}
          {new_state, {:error, format_exception(exception)}}
      catch
        kind, reason ->
          new_state = %{state | cache: '', counter: state.counter + 1}
          {new_state, {:error, format_error(kind, reason)}}
      end

    {:reply, {result, new_state.counter}, new_state, @idle_timeout}
  end

  @impl GenServer
  def handle_info(:timeout, config) do
    {:stop, :timeout, config}
  end

  # Well-formed input, evaluate if safe.
  defp eval({:ok, forms}, _code, state) do
    {result, binding, env} = :elixir.eval_forms(forms, state.binding, state.env)

    new_state = %{
      binding: binding,
      cache: '',
      counter: state.counter + 1,
      env: env
    }

    {new_state, {:ok, result}}
  end

  # Input is not complete, update the cache and wait for more input.
  defp eval({:error, {_line, _error, ""}}, code, state) do
    {%{state | cache: code}, :incomplete}
  end

  # Malformed input.
  defp eval({:error, {line, error, token}}, _code, _state) do
    :elixir_errors.parse_error(line, "iex", error, token)
  end

  defp format_exception(exception) do
    "** (#{inspect(exception.__struct__)}) #{Exception.message(exception)}"
  end

  defp format_error(kind, reason) do
    "** (#{kind}) #{inspect(reason)}"
  end
end
