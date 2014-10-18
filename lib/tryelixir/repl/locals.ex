defmodule Tryelixir.Repl.Locals do
  @moduledoc """
  This module redefines a few functions that already exist in the stdlib so
  we can control each REPL process better.
  """

  @spec spawn((() -> any)) :: pid
  def spawn(fun) do
    check_spawn(Tryelixir.Watcher.spawn(self(), fun))
  end

  @spec spawn(module, atom, list) :: pid
  def spawn(mod, fun, args) do
    check_spawn(Tryelixir.Watcher.spawn(self(), mod, fun, args))
  end

  defp check_spawn({:ok, pid}), do: pid
  defp check_spawn({:error, :limit}) do
    raise PermissionError, description: "process limit reached"
  end
end
