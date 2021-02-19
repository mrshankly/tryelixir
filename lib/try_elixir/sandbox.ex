defmodule TryElixir.Sandbox do
  @moduledoc false

  use GenServer
  require Logger

  alias TryElixir.Sandbox.Checker
  alias TryElixir.Sandbox.WarningAgent

  @eval_timeout 5_000
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
    try do
      GenServer.call(pid, {:eval, code}, @eval_timeout)
    catch
      :exit, {:timeout, _} ->
        Process.exit(pid, :kill)
        :timeout
    end
  end

  @impl GenServer
  def init([]) do
    # Register a new warning agent as the :elixir_compiler_pid in the process dictionary.
    # This allows us to receive compiler warnings when calling :elixir.eval_forms/3.
    warning_agent = WarningAgent.start_link()
    :erlang.put(:elixir_compiler_pid, warning_agent)

    env = :elixir.env_for_eval(file: "iex", line: 1, delegate_locals_to: nil)
    state = %{binding: [], cache: '', counter: 1, env: env, warning_agent: warning_agent}

    Logger.info("sandbox: process start")
    {:ok, state, @idle_timeout}
  end

  @impl GenServer
  def handle_call({:eval, input}, _from, state) do
    Logger.debug("sandbox: eval input: #{inspect(input)}")
    code = state.cache ++ String.to_charlist(input)

    # Flush warnings that were left behind from a previous eval.
    WarningAgent.flush(state.warning_agent)

    {new_state, result, output} =
      try do
        quoted = Code.string_to_quoted(code, file: "iex", line: state.counter)
        eval(quoted, code, state)
      rescue
        exception ->
          if exception.__struct__ == TryElixir.SandboxError do
            Logger.warn("sandbox: forbidden code: #{inspect(code)}")
          end

          new_state = %{state | cache: '', counter: state.counter + 1}
          {new_state, {:error, format_exception(exception)}, ""}
      catch
        kind, reason ->
          new_state = %{state | cache: '', counter: state.counter + 1}
          {new_state, {:error, format_error(kind, reason)}, ""}
      end

    warnings = WarningAgent.flush(state.warning_agent)
    reply = {result, output, warnings, new_state.counter}

    Logger.debug("sandbox: eval reply: #{inspect(reply)}")
    {:reply, reply, new_state, @idle_timeout}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    Logger.info("sandbox: idle timeout")
    {:stop, :normal, state}
  end

  # Well-formed input, evaluate if safe.
  defp eval({:ok, forms}, _code, state) do
    safe_eval = fn ->
      Checker.safe!(forms, state.env) |> :elixir.eval_forms(state.binding, state.env)
    end

    {{result, binding, env}, output} = capture_output(safe_eval)

    new_state = %{
      binding: binding,
      cache: '',
      counter: state.counter + 1,
      env: env,
      warning_agent: state.warning_agent
    }

    {new_state, {:ok, result}, output}
  end

  # Input is not complete, update the cache and wait for more input.
  defp eval({:error, {_line, _error, ""}}, code, state) do
    {%{state | cache: code ++ '\n'}, :incomplete, ""}
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

  defp capture_output(fun) when is_function(fun, 0) do
    current_gl = Process.group_leader()
    {:ok, capture_gl} = StringIO.open("", capture_prompt: false, encoding: :unicode)

    try do
      Process.group_leader(self(), capture_gl)
      fun.()
    catch
      kind, reason ->
        _ = StringIO.close(capture_gl)
        :erlang.raise(kind, reason, __STACKTRACE__)
    else
      result ->
        {:ok, {_input, output}} = StringIO.close(capture_gl)
        {result, output}
    after
      Process.group_leader(self(), current_gl)
    end
  end
end
