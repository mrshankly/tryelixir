ExUnit.start

defmodule Tryelixir.Case do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use ExUnit.Case
      import unquote(__MODULE__)
    end
  end

  @doc """
  Runs Tryelixir.Eval eval_loop, feeds the provided input and returns the
  produced output. The header and whitespaces are stripped.
  """
  def capture_output(input) do
    ExUnit.CaptureIO.capture_io([input: input, capture_prompt: false],
      fn -> Tryelixir.Eval.start() end) |> strip_output
  end

  defp strip_output(string) do
    string
    |> strip_line # strip the greeting
    |> String.strip
  end

  defp strip_line(string) do
    Regex.replace %r/\A.+?$/ms, string, ""
  end
end
