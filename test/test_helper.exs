ExUnit.start()

defmodule TryElixir.Case do
  def eval(code) do
    {:ok, initial_state, _} = TryElixir.Sandbox.init([])
    eval(code, initial_state)
  end

  def eval(code, state) do
    {:reply, {result, _, _}, new_state, _} =
      TryElixir.Sandbox.handle_call({:eval, code}, self(), state)

    {result, new_state}
  end
end
