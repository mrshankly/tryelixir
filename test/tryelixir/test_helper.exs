ExUnit.start

defmodule Tryelixir.Case do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use ExUnit.Case
      import unquote(__MODULE__)
    end
  end

  def start_eval() do
    Tryelixir.Eval.start
    |> Process.register(:test_eval)
  end

  @doc """
  Sends the input to a eval_loop process and returns the response.
  """
  def test_eval(input) do
    :test_eval <- {self, {:input, input}}
    receive do
      response ->
        response
    end
  end
end
