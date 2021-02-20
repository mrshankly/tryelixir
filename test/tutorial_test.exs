defmodule TutorialTest do
  @moduledoc """
  Tests with code from the tutorial shown to users.
  """

  use ExUnit.Case, async: true
  import TryElixir.Case

  setup_all do
    {:ok, pid} = TryElixir.Sandbox.start()
    [pid: pid]
  end

  test "1 - warm up", %{pid: pid} do
    {:ok, result} = eval(pid, ~s/IO.puts("Hello, world!")/)
    assert result == :ok
    {:ok, result} = eval(pid, "8 + 4")
    assert result == 12
  end

  test "2 - basics", %{pid: pid} do
    {:ok, result} = eval(pid, "20 - 6")
    assert result == 14

    {:ok, result} = eval(pid, "6 * 3")
    assert result == 18

    {:ok, result} = eval(pid, "12 / 3")
    assert result == 4.0

    {:ok, result} = eval(pid, "div(12, 3)")
    assert result == 4
  end

  test "3 - atoms", %{pid: pid} do
    {:ok, result} = eval(pid, ":atom")
    assert result == :atom

    {:ok, result} = eval(pid, ~s(:"I'm still an atom"))
    assert result == :"I'm still an atom"
  end

  test "4 - tuples", %{pid: pid} do
    {:ok, result} = eval(pid, "{:radius, 20}")
    assert result == {:radius, 20}

    {:ok, result} = eval(pid, "{:foo, :bar, 123}")
    assert result == {:foo, :bar, 123}

    {:ok, result} = eval(pid, "elem({1, 2, 3}, 0)")
    assert result == 1

    {:ok, result} = eval(pid, "put_elem({:one, :two, :three}, 0, :four)")
    assert result == {:four, :two, :three}
  end

  test "5 - lists", %{pid: pid} do
    {:ok, result} = eval(pid, "[1, 2, 3]")
    assert result == [1, 2, 3]

    {:ok, result} = eval(pid, "[1, :two, [3, 4]]")
    assert result == [1, :two, [3, 4]]

    {:ok, result} = eval(pid, "[head | tail] = [1, 2, 3]")
    assert result == [1, 2, 3]

    {:ok, result} = eval(pid, "head")
    assert result == 1

    {:ok, result} = eval(pid, "tail")
    assert result == [2, 3]
  end

  test "6 - strings and char lists", %{pid: pid} do
    {:ok, result} = eval(pid, ~s/is_binary("hello")/)
    assert result

    {:ok, result} = eval(pid, "is_list('hello')")
    assert result

    {:ok, result} = eval(pid, ~s("hello" == 'hello'))
    refute result

    {:ok, result} = eval(pid, ~s("héllò"))
    assert result == "héllò"

    {:ok, result} = eval(pid, "?a")
    assert result == ?a

    {:ok, result} = eval(pid, "[?a, ?b, ?c]")
    assert result == 'abc'

    {:ok, result} = eval(pid, "[?a, ?b, ?c, 1]")
    assert result == [?a, ?b, ?c, 1]
  end

  test "7 - variables", %{pid: pid} do
    {:ok, result} = eval(pid, "age = 25")
    assert result == 25

    {:ok, result} = eval(pid, "age")
    assert result == 25
  end

  test "8 - pattern matching", %{pid: pid} do
    {:ok, result} = eval(pid, "{1, a} = {1, 2}")
    assert result == {1, 2}

    {:ok, result} = eval(pid, "a")
    assert result == 2

    {:error, result} = eval(pid, "{a, b, c} = {1, 2}")
    assert result == "** (MatchError) no match of right hand side value: {1, 2}"

    {:ok, result} = eval(pid, "x = 1")
    assert result == 1

    {:ok, result} = eval(pid, "^x = 1")
    assert result == 1

    {:error, result} = eval(pid, "^x = 2")
    assert result == "** (MatchError) no match of right hand side value: 2"
  end

  test "9 - functions", %{pid: pid} do
    {:ok, _} = eval(pid, "double = fn(x) -> x * 2 end")

    {:ok, result} = eval(pid, "double.(3)")
    assert result == 6

    {:ok, result} = eval(pid, "Enum.map([1, 2, 3], fn(x) -> x * 2 end)")
    assert result == [2, 4, 6]

    {:ok, result} = eval(pid, "Enum.map [1, 2, 3], double")
    assert result == [2, 4, 6]

    g = """
      g = fn
        x, y when x > 0 -> x + y
        x, y -> x * y
      end
    """

    {:ok, _} = eval(pid, g)

    {:ok, result} = eval(pid, "g.(1, 3)")
    assert result == 4

    {:ok, result} = eval(pid, "g.(-1, 3)")
    assert result == -3
  end

  test "10 - modules", %{pid: pid} do
    math = """
      defmodule Math do
        def sum(a, b) do
          a + b
        end

        def square(x) do
          x * x
        end
      end
    """

    {:ok, _} = eval(pid, math)

    {:ok, result} = eval(pid, "Math.sum(3, 6)")
    assert result == 9

    {:ok, result} = eval(pid, "Math.square(3)")
    assert result == 9

    private_math = """
      defmodule PrivateMath do
        def sum(a, b) do
          do_sum(a, b)
        end

        defp do_sum(a, b) do
          a + b
        end
      end
    """

    {:ok, _} = eval(pid, private_math)

    {:ok, result} = eval(pid, "PrivateMath.sum(1, 2)")
    assert result == 3

    {:error, result} = eval(pid, "PrivateMath.do_sum(1, 2)")

    assert result ==
             "** (UndefinedFunctionError) function PrivateMath.do_sum/2 is undefined or private"
  end
end
