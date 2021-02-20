defmodule SandboxTest do
  use ExUnit.Case, async: true
  import TryElixir.Case

  @sandbox_error ~r/^\*\* \(TryElixir.SandboxError\)/

  test "literals" do
    {pid, {:ok, result}} = eval("42")
    assert result == 42

    {:ok, result} = eval(pid, ~s("foo"))
    assert result == "foo"

    {:ok, result} = eval(pid, "[1.0, :two, 'three']")
    assert result == [1.0, :two, 'three']
  end

  test "arithmetic" do
    {pid, {:ok, result}} = eval("1 + 1")
    assert result == 2

    {:ok, result} = eval(pid, "4 * 2 - 1")
    assert result == 7

    {:ok, result} = eval(pid, "(4 * (2 + 1 - 3) + 84) / 2")
    assert result === 42.0
  end

  test "local functions" do
    {_, {:ok, result}} = eval("abs(-1)")
    assert result == 1
  end

  test "binaries" do
    {pid, {:ok, result}} = eval("<<128 :: size(8)-unit(4)>>")
    assert result == <<128::size(8)-unit(4)>>

    {:error, result} = eval(pid, "<<128 :: size(256)-unit(4)>>")
    assert result =~ @sandbox_error

    {:error, result} = eval(pid, "<<128 :: size(8)-unit(32)>>")
    assert result =~ @sandbox_error

    {:ok, _} = eval(pid, "n = 8")

    {:error, result} = eval(pid, "<<128 :: size(n)>>")
    assert result =~ @sandbox_error

    {:error, result} = eval(pid, "<<128 :: unit(n)>>")
    assert result =~ @sandbox_error
  end

  test "capture" do
    {pid, {:ok, result}} = eval("&System.version/0")
    assert result == (&System.version/0)

    {:error, result} = eval(pid, "&System.pid/0")
    assert result =~ @sandbox_error

    {:error, result} = eval(pid, "&File.cd/1")
    assert result =~ @sandbox_error

    {:error, result} = eval(pid, "&File.cd(&1)")
    assert result =~ @sandbox_error
  end

  test "arity" do
    {pid, {:ok, result}} = eval("IO.puts(\"Hello, world!\")")
    assert result == :ok

    {:error, result} = eval(pid, "IO.puts(:stderr, \"Hello, world!\")")
    assert result =~ @sandbox_error
  end

  test "module namespacing" do
    user1 = """
      defmodule Foo do
        def bar(), do: 1
      end
    """

    user2 = """
    defmodule Foo do
      def bar(), do: 2
    end
    """

    {pid1, {:ok, _}} = eval(user1)
    {pid2, {:ok, _}} = eval(user2)

    {:ok, result} = eval(pid1, "Foo.bar()")
    assert result == 1

    {:ok, result} = eval(pid2, "Foo.bar()")
    assert result == 2
  end

  test "user module redefinition" do
    math_sum = """
      defmodule Math do
        def sum(a, b), do: a + b
      end
    """

    {pid, {:ok, _}} = eval(math_sum)

    {:ok, result} = eval(pid, "Math.sum(21, 21)")
    assert result == 42

    math_square = """
      defmodule Math do
        def square(x), do: x * x
      end
    """

    {:ok, _} = eval(pid, math_square)

    {:ok, result} = eval(pid, "Math.square(8)")
    assert result == 64

    {:error, result} = eval(pid, "Math.sum(11, 4)")
    assert result == "** (UndefinedFunctionError) function Math.sum/2 is undefined or private"
  end

  test "reserved module redefinition" do
    kernel = """
      defmodule Kernel do
        def foo(), do: 0
      end
    """

    {_, {:error, result}} = eval(kernel)
    assert result =~ @sandbox_error
  end
end
