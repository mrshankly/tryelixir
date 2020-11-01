defmodule SandboxTest do
  use ExUnit.Case, async: true
  import TryElixir.Case

  @sandbox_error ~r/^\*\* \(TryElixir.SandboxError\)/

  test "literals" do
    {{:ok, result}, _} = eval("42")
    assert result == 42

    {{:ok, result}, _} = eval(~s("foo"))
    assert result == "foo"

    {{:ok, result}, _} = eval("[1.0, :two, 'three']")
    assert result == [1.0, :two, 'three']
  end

  test "arithmetic" do
    {{:ok, result}, _} = eval("1 + 1")
    assert result == 2

    {{:ok, result}, _} = eval("4 * 2 - 1")
    assert result == 7

    {{:ok, result}, _} = eval("(4 * (2 + 1 - 3) + 84) / 2")
    assert result === 42.0
  end

  test "local functions" do
    {{:ok, result}, _} = eval("self()")
    assert result == self()
  end

  test "binaries" do
    {{:ok, result}, _} = eval("<<128 :: size(8)-unit(4)>>")
    assert result == <<128::size(8)-unit(4)>>

    {{:error, result}, _} = eval("<<128 :: size(256)-unit(4)>>")
    assert result =~ @sandbox_error

    {{:error, result}, _} = eval("<<128 :: size(8)-unit(32)>>")
    assert result =~ @sandbox_error

    {{:ok, _}, state} = eval("n = 8")

    {{:error, result}, state} = eval("<<128 :: size(n)>>", state)
    assert result =~ @sandbox_error

    {{:error, result}, _} = eval("<<128 :: unit(n)>>", state)
    assert result =~ @sandbox_error
  end

  test "capture" do
    {{:ok, result}, _} = eval("&System.version/0")
    assert result == (&System.version/0)

    {{:error, result}, _} = eval("&System.pid/0")
    assert result =~ @sandbox_error

    {{:error, result}, _} = eval("&File.cd/1")
    assert result =~ @sandbox_error

    {{:error, result}, _} = eval("&File.cd(&1)")
    assert result =~ @sandbox_error
  end
end
