Dynamo.under_test(Tryelixir.Dynamo)
Dynamo.Loader.enable
ExUnit.start

defmodule Tryelixir.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  # Enable code reloading on test cases
  setup do
    Dynamo.Loader.enable
    :ok
  end

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
      fn -> Tryelixir.Eval.eval_loop() end) |> strip_output
  end

  defp strip_output(string) do
    string
    |> strip_line # strip the greeting and colors
    |> String.strip
  end

  defp strip_line(string) do
    string = Regex.replace %r/\A.+?$/ms, string, ""
    Regex.replace %r/\e\[.?.?m/, string, ""
  end
end
