defmodule TryElixir.Sandbox.WarningAgent do
  @moduledoc """
  A simple abstraction that allows a sandbox process to store and retrieve
  warning messages from the elixir compiler.

  The process must be registered as `:elixir_compiler_pid` in the process
  dictionary.
  """

  require Logger

  @type warning() :: {non_neg_integer(), charlist() | nil, charlist()}

  @spec start_link :: pid()
  def start_link do
    spawn_link(fn -> warning_agent([]) end)
  end

  @spec flush(pid()) :: [warning()]
  def flush(agent) do
    ref = make_ref()
    send(agent, {:flush, self(), ref})

    receive do
      {^ref, warnings} -> warnings
    end
  end

  defp warning_agent(warnings) when is_list(warnings) do
    receive do
      {:warning, file, line, message} ->
        warning_agent([{file, line, to_string(message)} | warnings])

      {:flush, from, ref} ->
        send(from, {ref, Enum.reverse(warnings)})
        warning_agent([])

      {:module_available, from, ref, _, _, _, _} ->
        send(from, {ref, :ack})
        warning_agent(warnings)

      message ->
        Logger.debug("warning agent: unknown message: #{inspect(message)}")
        warning_agent(warnings)
    end
  end
end
