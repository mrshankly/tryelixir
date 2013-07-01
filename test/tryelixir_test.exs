Code.require_file "test_helper.exs", __DIR__

defmodule TryelixirTest do
  use Tryelixir.Case

  @restricted "** (RuntimeError) restricted"

  test "normal input" do
    assert capture_output("1 + 1") == "2"
  end

  test "allowed module" do
    assert capture_output("Enum.map([1,2,3], &1 * 2)") == "[2,4,6]"
  end

  test "allowed module with fn" do
    assert capture_output("Enum.map([1,2,3], fn(x) -> x + 1 end)") == "[2,3,4]"
  end

  test "restricted module" do
    assert capture_output("IO.puts \"Hello world!\"") == @restricted
  end

  test "restricted fn" do
    assert capture_output("fn -> System.cmd(pwd) end") == @restricted
  end

  test "restricted local function (no args)" do
    assert capture_output("ls") == @restricted
  end

  test "restricted local function" do
    assert capture_output("ls(\"1\")") == @restricted
  end

  test "restricted local function with fn" do
    assert capture_output("spawn(fn -> 1 + 1 end)") == @restricted
  end
end
