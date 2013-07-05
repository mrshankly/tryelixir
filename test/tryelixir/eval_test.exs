Code.require_file "test_helper.exs", __DIR__

defmodule TryelixirTest do
  use Tryelixir.Case

  @restricted "** (RuntimeError) restricted"

  start_eval

  test "normal input" do
    assert {_, {"ok", 2}} = test_eval("1 + 1")
  end

  test "allowed module" do
    assert {_, {"ok", [2,4,6]}} = test_eval("Enum.map([1,2,3], &1 * 2)")
  end

  test "allowed module with fn" do
    assert {_, {"ok", [2,3,4]}} = test_eval("Enum.map([1,2,3], fn(x) -> x + 1 end)")
  end

  test "restricted module" do
    assert {_, {"error", @restricted}} = test_eval("IO.puts \"Hello world!\"")
  end

  test "restricted fn" do
    assert {_, {"error", @restricted}} = test_eval("fn -> System.cmd(\"pwd\") end")
  end

  test "allowed fn" do
    test_eval("square = fn(x) -> x * x end")
    assert {_, {"ok", 25}} = test_eval("square.(5)")
  end

  test "restricted local function (no args)" do
    assert {_, {"error", @restricted}} = test_eval("self")
  end

  test "restricted local function" do
    assert {_, {"error", @restricted}} = test_eval("ls(\".\")")
  end

  test "restricted local function with fn" do
    assert {_, {"error", @restricted}} = test_eval("spawn(fn -> 1 + 1 end)")
  end

  test "Kernel access" do
    test_eval("foo = [a: 1, b: 2, c: 3]")
    assert {_, {"ok", 2}} = test_eval("foo[:b]")
  end
end
