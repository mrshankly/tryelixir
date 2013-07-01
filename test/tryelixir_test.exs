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
    assert capture_output("fn -> System.cmd(\"pwd\") end") == @restricted
  end

  test "allowed fn call" do
    input = """
      square = fn(x) -> x * x end
      square.(5)
    """
    assert [_, "25"] = String.split(capture_output(input), "\n", global: false)
  end

  test "restricted fn call" do
    input = """
      f = fn -> System.cmd("pwd") end
      f.()
    """
    assert [@restricted, _] = String.split(capture_output(input), "\n", global: false)
  end

  test "restricted local function (no args)" do
    assert capture_output("ls") == @restricted
  end

  test "restricted local function" do
    assert capture_output("ls(\".\")") == @restricted
  end

  test "restricted local function with fn" do
    assert capture_output("spawn(fn -> 1 + 1 end)") == @restricted
  end

  test "Kernel access" do
    input = """
      foo = [a: 1, b: 2, c: 3]
      foo[:b]
    """
    assert capture_output(input) == "[a: 1, b: 2, c: 3]\n2"
  end
end
