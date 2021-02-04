defmodule TutorialTest do
  @moduledoc """
  Tests with code from the tutorial shown to users.
  """

  use ExUnit.Case, async: true
  import TryElixir.Case

  test "1 - warm up" do
    {{:ok, result}, _} = eval(~s/IO.puts("Hello, world!")/)
    assert result == :ok
    {{:ok, result}, _} = eval("8 + 4")
    assert result == 12
  end

  test "2 - basics" do
    {{:ok, result}, _} = eval("20 - 6")
    assert result == 14

    {{:ok, result}, _} = eval("6 * 3")
    assert result == 18

    {{:ok, result}, _} = eval("12 / 3")
    assert result == 4.0

    {{:ok, result}, _} = eval("div(12, 3)")
    assert result == 4
  end

  test "3 - atoms" do
    {{:ok, result}, _} = eval(":atom")
    assert result == :atom

    {{:ok, result}, _} = eval(~s(:"I'm still an atom"))
    assert result == :"I'm still an atom"
  end

  test "4 - tuples" do
    {{:ok, result}, _} = eval("{:radius, 20}")
    assert result == {:radius, 20}

    {{:ok, result}, _} = eval("{:foo, :bar, 123}")
    assert result == {:foo, :bar, 123}

    {{:ok, result}, _} = eval("elem({1, 2, 3}, 0)")
    assert result == 1

    {{:ok, result}, _} = eval("put_elem({:one, :two, :three}, 0, :four)")
    assert result == {:four, :two, :three}
  end

  test "5 - lists" do
    {{:ok, result}, _} = eval("[1, 2, 3]")
    assert result == [1, 2, 3]

    {{:ok, result}, _} = eval("[1, :two, [3, 4]]")
    assert result == [1, :two, [3, 4]]

    {{:ok, result}, state} = eval("[head | tail] = [1, 2, 3]")
    assert result == [1, 2, 3]

    {{:ok, result}, state} = eval("head", state)
    assert result == 1

    {{:ok, result}, _} = eval("tail", state)
    assert result == [2, 3]
  end

  test "6 - strings and char lists" do
    {{:ok, result}, _} = eval(~s/is_binary("hello")/)
    assert result

    {{:ok, result}, _} = eval("is_list('hello')")
    assert result

    {{:ok, result}, _} = eval(~s("hello" == 'hello'))
    refute result

    {{:ok, result}, _} = eval(~s("héllò"))
    assert result == "héllò"

    {{:ok, result}, _} = eval("?a")
    assert result == ?a

    {{:ok, result}, _} = eval("[?a, ?b, ?c]")
    assert result == 'abc'

    {{:ok, result}, _} = eval("[?a, ?b, ?c, 1]")
    assert result == [?a, ?b, ?c, 1]
  end

  test "7 - variables" do
    {{:ok, result}, state} = eval("age = 25")
    assert result == 25

    {{:ok, result}, _} = eval("age", state)
    assert result == 25
  end

  test "8 - pattern matching" do
    {{:ok, result}, state} = eval("{1, a} = {1, 2}")
    assert result == {1, 2}

    {{:ok, result}, state} = eval("a", state)
    assert result == 2

    {{:error, result}, state} = eval("{a, b, c} = {1, 2}", state)
    assert result == "** (MatchError) no match of right hand side value: {1, 2}"

    {{:ok, result}, state} = eval("x = 1", state)
    assert result == 1

    {{:ok, result}, state} = eval("^x = 1", state)
    assert result == 1

    {{:error, result}, _} = eval("^x = 2", state)
    assert result == "** (MatchError) no match of right hand side value: 2"
  end

  test "9 - functions" do
    {{:ok, _}, state} = eval("double = fn(x) -> x * 2 end")

    {{:ok, result}, state} = eval("double.(3)", state)
    assert result == 6

    {{:ok, result}, state} = eval("Enum.map([1, 2, 3], fn(x) -> x * 2 end)", state)
    assert result == [2, 4, 6]

    {{:ok, result}, state} = eval("Enum.map [1, 2, 3], double", state)
    assert result == [2, 4, 6]

    g = """
      g = fn
        x, y when x > 0 -> x + y
        x, y -> x * y
      end
    """

    {{:ok, _}, state} = eval(g, state)

    {{:ok, result}, state} = eval("g.(1, 3)", state)
    assert result == 4

    {{:ok, result}, _} = eval("g.(-1, 3)", state)
    assert result == -3
  end

  test "10 - modules" do
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

    {{:ok, _}, state} = eval(math)

    {{:ok, result}, state} = eval("Math.sum(3, 6)", state)
    assert result == 9

    {{:ok, result}, state} = eval("Math.square(3)", state)
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

    {{:ok, _}, state} = eval(private_math, state)

    {{:ok, result}, state} = eval("PrivateMath.sum(1, 2)", state)
    assert result == 3

    {{:error, result}, _} = eval("PrivateMath.do_sum(1, 2)", state)

    assert result ==
             "** (UndefinedFunctionError) function PrivateMath.do_sum/2 is undefined or private"
  end
end
