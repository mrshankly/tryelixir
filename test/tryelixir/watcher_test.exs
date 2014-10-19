defmodule Tryelixir.WatcherTest do
  use ExUnit.Case, async: true

  import Tryelixir.Watcher, only: [spawn: 2, spawn: 4]

  setup do
    long_fn = fn ->
      receive do
        _ -> :ok
      end
    end
    short_fn = fn -> :ok end
    max = Tryelixir.Watcher.max

    {:ok, [max: max, long_fn: long_fn, short_fn: short_fn]}
  end

  test "spawn/1", %{short_fn: f} do
    Tryelixir.Watcher.add(1)
    assert elem(spawn(1, f), 0) == :ok
  end

  test "spawn/3", _context do
    Tryelixir.Watcher.add(2)
    assert elem(spawn(2, Kernel, :+, [1, 1]), 0) == :ok
  end

  test "spawn limit", %{max: max, long_fn: f} do
    Tryelixir.Watcher.add(3)

    Enum.each(1..max, fn(_) ->
      assert elem(spawn(3, f), 0) == :ok
    end)
    assert spawn(3, f) == {:error, :limit}
  end

  test "free after limit", %{max: max, long_fn: lf, short_fn: sf} do
    Tryelixir.Watcher.add(4)

    Enum.map(1..max, fn(_) -> spawn(4, lf) end)
    |> Enum.each(fn({:ok, p}) -> send(p, :stop) end)

    :timer.sleep(100) # waits for tables

    assert elem(spawn(4, sf), 0) == :ok
  end
end
