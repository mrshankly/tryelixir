Code.require_file "test_helper.exs", __DIR__

defmodule TryelixirTest do
  use Tryelixir.Case

  @restricted "** (RuntimeError) restricted"

  test "normal input" do
    assert capture_output("1 + 1") == "2"
  end

  test "restricted module" do
  	assert capture_output("IO.puts \"Hello world!\"") == @restricted
  end
end
