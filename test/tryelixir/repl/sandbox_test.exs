defmodule Tryelixir.Repl.SandboxTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = Tryelixir.Repl.new
    eval = &elem(Tryelixir.Repl.eval(pid, &1), 1)
    {:ok, [eval: eval]}
  end

  test "allowed local", %{eval: eval} do
    assert eval.("1 + 2") == "3"
    assert eval.("elem {1,2,3}, 0") == "1"
    assert eval.("elem({1,2,3}, 1) == 2") == "true"
  end

  test "restricted local", %{eval: eval} do
    assert eval.("node") =~ "PermissionError"
    assert eval.("node()") =~ "PermissionError"
    assert eval.("apply(fn x -> x + 1 end, 9)") =~ "PermissionError"
  end

  test "allowed non-local", %{eval: eval} do
    assert eval.("List.first([1,2,3])") == "1"
    assert eval.("Enum.map(1..5, &(&1 * &1))") == "[1, 4, 9, 16, 25]"
    assert eval.("Enum.map(1..5, fn(x) -> x + 1 end)") == "[2, 3, 4, 5, 6]"
  end

  test "restricted non-local", %{eval: eval} do
    assert eval.("Macro.escape(:foo)") =~ "PermissionError"
  end

  test "allowed user module", %{eval: eval} do
    mod = """
    defmodule SimpleMath do
      # Simple module, it should compile and everything should be allowed.

      @pi 3.14

      # API.

      def square(a) when is_number(a) do
        a * a
      end

      def sum_pos(a, b) when a > 0 and b > 0 do
        do_sum(a, b)
      end

      def double(a) when is_number(a) do
        do_sum(a, a)
      end

      def circle_area(radius) do
        @pi * square(radius)
      end

      def useless do
        2 * my_const
      end

      # Helpers.

      defp do_sum(a, b), do: a + b

      defp my_const(), do: 123
    end
    """

    assert eval.(mod) =~ ~r"^{:module, SimpleMath"
    assert eval.("SimpleMath.sum_pos(5, 20)") == "25"
    assert eval.("SimpleMath.circle_area(3)") == "28.26"
    assert eval.("SimpleMath.useless") == "246"
  end

  test "nested user module", %{eval: eval} do
    mod = """
    defmodule One do
      defmodule Two do
        defmodule Three do
          def four, do: 4
        end
      end
    end
    """

    assert eval.(mod) =~ ~r"^{:module, One"
    assert eval.("One.Two.Three.four") == "4"
  end

  test "restricted user module 1", %{eval: eval} do
    mod = """
    defmodule Rogue do
      # Module that contains code that is not allowed, it should not compile.

      defmodule Rogue.Bad do
        def make_ref() do
          :ref
        end
      end

      def ref() do
        make_ref # The module should fail because of this.
      end

      def where_am_i?() do
        System.cmd("pwd", [])
      end
    end
    """

    assert eval.(mod) =~ "restricted function: make_ref/0"
    assert eval.("Rogue.ref") =~ "PermissionError"
  end

  test "restricted user module 2", %{eval: eval} do
    mod = """
    defmodule BadMod do
      defmodule BadMod.Nested do
        # Here we defined a function named node to try to trick it into thinking
        # node/1 is now allowed.
        def node(x) do
          :localhost
        end
      end

      def normal_fun(x) do
        node(x) # This should definitly not run.
      end
    end
    """

    assert eval.(mod) =~ "restricted function: node/1"
    assert eval.("BadMod.normal_fun(self())") =~ "PermissionError"
  end

  test "module redefinition", %{eval: eval} do
    good_one = """
    defmodule Good do
      def ok, do: :ok
    end
    """
    good_two = """
    defmodule Good do
      def ok, do: :new_ok
    end
    """
    bad_mod = """
    defmodule Enum do
      def ok, do: :ok
    end
    """

    assert eval.(good_one) =~ ~r"^{:module, Good"
    assert eval.("Good.ok") == ":ok"

    assert eval.(good_two) =~ ~r"^{:module, Good"
    assert eval.("Good.ok") == ":new_ok"

    assert eval.(bad_mod) =~ "PermissionError"
  end

  test "anonymous functions", %{eval: eval} do
    assert eval.("fn(x) -> x * 2 end") =~ ~r"^#Function<"

    assert eval.("&make_ref") =~ "PermissionError"
    assert eval.("fn(x) -> node(x) end") =~ "PermissionError"

    assert eval.("&Code.eval_string(&1)") =~ "PermissionError"
    assert eval.("fn -> Code.eval_string(\"1 + 1\") end") =~ "PermissionError"
  end

  test "multi-clause anonymous functions", %{eval: eval} do
    assert eval.("""
      f = fn
        x, y when x > 0 -> x * y
        x, y -> x + y
      end
    """) =~ ~r"^#Function<"
    assert eval.("f.(10, 4)") == "40"
    assert eval.("f.(-1, 5)") == "4"

    assert eval.("""
      xf = fn
        x, y -> x + y
        z -> node(z)
      end
    """) =~ "PermissionError"
  end

  test "variables", %{eval: eval} do
    assert eval.("a = 1") == "1"
    assert eval.("a") == "1"
  end

  test "variables with restricted local", %{eval: eval} do
    assert eval.("node") =~ "PermissionError"
    assert eval.("node = 1") == "1"
    assert eval.("node") == "1"
    assert eval.("node()") =~ "PermissionError"
  end

  test "variables with anonymous functions", %{eval: eval} do
    assert eval.("spawn_monitor = fn(x) -> :ok end") =~ ~r"^#Function<"
    assert eval.("spawn_monitor.(fn -> 1 end)") == ":ok"
    assert eval.("spawn_monitor(fn -> 1 end)") =~ "PermissionError"
  end

  test "list size", %{eval: eval} do
    list = "#{inspect Enum.to_list(1..1000), limit: 1000, pretty: false}"
    assert eval.("[1, 2]") == "[1, 2]"
    assert eval.(list) =~ "PermissionError"
  end

  test "restricted list", %{eval: eval} do
    assert eval.(~S{[1, 2, &System.cmd("pwd", [])]}) =~ "PermissionError"
  end

  test "range size", %{eval: eval} do
    assert eval.("1..47") == "1..47"
    assert eval.("+20..147") =~ "PermissionError"
    assert eval.("200..500") =~ "PermissionError"
    assert eval.("-100..-500") =~ "PermissionError"
  end

  test "access", %{eval: eval} do
    assert eval.("kv = [a: 1, b: 2]") == "[a: 1, b: 2]"
    assert eval.("kv[:a]") == "1"

    assert eval.("map = %{a: 1, b: 2}") == "%{a: 1, b: 2}"
    assert eval.("map.a") == "1"

    assert eval.(~S[fm = %{"one" => 1.0, "two" => 2.0}]) == ~S[%{"one" => 1.0, "two" => 2.0}]
    assert eval.(~S{fm["one"]}) == "1.0"
  end
end
