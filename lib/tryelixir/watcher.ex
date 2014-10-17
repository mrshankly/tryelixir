defmodule Tryelixir.Watcher do
  @moduledoc false

  use GenServer

  @max 5 # Maximum number of active processes.

  # API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add(pid) do
    GenServer.cast(__MODULE__, {:add, pid})
  end

  def spawn(pid, fun) do
    GenServer.call(__MODULE__, {:spawn, pid, fun})
  end

  def max(), do: @max

  # GenServer callbacks.

  def init([]) do
    ps = :ets.new(:tryelixir_pidt, [:set, :protected])
    rs = :ets.new(:tryelixir_reft, [:set, :protected])
    {:ok, {ps, rs}}
  end

  def handle_call({:spawn, pid, fun}, _from, {ps, rs}) do
    max = @max + 1
    new = :ets.update_counter(ps, pid, {2, 1, max, max})

    reply = if new < max do
      {p, ref} = spawn_monitor(fun)
      :ets.insert(rs, {ref, pid})
      {:ok, p}
    else
      :ets.update_counter(ps, pid, {2, -1, 0, 0})
      {:error, :limit}
    end

    {:reply, reply, {ps, rs}}
  end

  def handle_call(_msg, _from, tables) do
    {:noreply, tables}
  end

  def handle_cast({:add, pid}, tables = {ps, _}) do
    :ets.insert(ps, {pid, 0})
    {:noreply, tables}
  end

  def handle_cast(_msg, tables) do
    {:noreply, tables}
  end

  def handle_info({:DOWN, ref, :process, _pid, _info}, {ps, rs}) do
    pid = :ets.lookup_element(rs, ref, 2)
    :ets.delete(rs, ref)
    :ets.update_counter(ps, pid, {2, -1, 0, 0})
    {:noreply, {ps, rs}}
  end

  def handle_info(_msg, tables) do
    {:noreply, tables}
  end
end
