ExUnit.start()

defmodule TryElixir.Case do
  def eval(code) do
    {:ok, pid} = TryElixir.Sandbox.start()
    {pid, eval(pid, code)}
  end

  def eval(pid, code) do
    case TryElixir.Sandbox.eval(pid, code) do
      {result, _, _, _} -> result
      :timeout -> :timeout
    end
  end
end
