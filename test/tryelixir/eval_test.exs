Code.require_file("test_helper.exs", __DIR__)

defmodule TryelixirTest do
  use Tryelixir.Case

  @restricted "** (RuntimeError) restricted"

  start_eval

  test "normal input" do
    assert {_, {"ok", 2}} = test_eval("1 + 1")
  end

  test "allowed module" do
    assert {_, {"ok", [2, 4, 6]}} = test_eval("Enum.map([1,2,3], fn(x) -> x * 2 end)")
  end

  test "allowed module with fn" do
    assert {_, {"ok", [2, 3, 4]}} = test_eval("Enum.map([1,2,3], fn(x) -> x + 1 end)")
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

  test "undefined local" do
    assert {_, {"error", "** (CompileError) " <> _}} =
             test_eval("ls")
  end

  test "kernel access" do
    test_eval("foo = [a: 1, b: 2, c: 3]")
    assert {_, {"ok", 2}} = test_eval("foo[:b]")
  end

  test "user defined module" do
    Enum.each(
      ["defmodule Test do", "  def square(x) when is_integer(x) do", "    x * x", "  end", "end"],
      &test_eval/1
    )

    assert {_, {"ok", 25}} = test_eval("Test.square(5)")
  end

  test "restricted user defined module" do
    Enum.each(
      ["defmodule Rtest do", "  def rspawn(fun) do", "    spawn(fun)", "  end", "end"],
      &test_eval/1
    )

    assert {_, {"error", @restricted}} =
             test_eval("Rtest.rspawn(fn -> Enum.map(1..10, fn(x) -> x end) end)")
  end
end
