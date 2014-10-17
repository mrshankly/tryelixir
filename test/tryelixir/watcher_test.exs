defmodule Tryelixir.WatcherTest do
  use ExUnit.Case, async: true

  test "watcher spawn" do
    pid = 1
    Tryelixir.Watcher.add(pid)
    assert elem(Tryelixir.Watcher.spawn(pid, fn -> :ok end), 0) == :ok
  end

  test "watcher spawn limit" do
    pid = 1
    max = Tryelixir.Watcher.max()
    long_fn = fn ->
      receive do
        _ -> :ok
      end
    end

    Tryelixir.Watcher.add(pid)
    Enum.each(1..max, fn(_) -> Tryelixir.Watcher.spawn(pid, long_fn) end)

    assert Tryelixir.Watcher.spawn(pid, long_fn) == {:error, :limit}
  end

  test "watcher clean spawn limit" do
    pid = 1
    max = Tryelixir.Watcher.max()
    long_fn = fn ->
      receive do
        _ -> :ok
      end
    end

    Tryelixir.Watcher.add(pid)
    ps = Enum.map(1..max, fn(_) -> Tryelixir.Watcher.spawn(pid, long_fn) end)
    Enum.each(ps, fn({:ok, p}) -> send(p, :stop) end) # stop all processes

    :timer.sleep(50) # waits for tables to be cleaned

    assert elem(Tryelixir.Watcher.spawn(pid, fn -> :ok end), 0) == :ok
  end
end
