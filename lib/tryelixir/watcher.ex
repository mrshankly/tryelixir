defmodule Tryelixir.Watcher do
  @moduledoc """
  Responsible for limiting the number of active processes from a certain pid.

  It uses 2 ETS tables to keep track of everything. One table keeps track of
  the "parent" pids and their active process count. The second table has all
  the monitor references of the active processes relative to a certain
  "parent" process.

  A process should be created with either `Tryelixir.Watcher.spawn/1` or
  `Tryelixir.Watcher.spawn/3`.
  """

  use GenServer

  @max 5 # Maximum number of active processes.

  # API

  @spec start_link() :: {:ok, pid} | {:error, term}
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec add(pid) :: :ok
  def add(pid) do
    GenServer.cast(__MODULE__, {:add, pid})
  end

  @spec remove(pid) :: :ok
  def remove(pid) do
    GenServer.cast(__MODULE__, {:remove, pid})
  end

  @spec spawn(pid, (() -> any)) :: {:ok, pid} | {:error, term}
  def spawn(pid, fun) do
    GenServer.call(__MODULE__, {:spawn, pid, fun})
  end

  @spec spawn(pid, module, atom, list) :: {:ok, pid} | {:error, term}
  def spawn(pid, mod, fun, args) do
    GenServer.call(__MODULE__, {:spawn, pid, {mod, fun, args}})
  end

  @spec max() :: non_neg_integer
  def max(), do: @max

  # GenServer callbacks.

  def init([]) do
    ps = :ets.new(:tryelixir_pidt, [:set, :protected])
    rs = :ets.new(:tryelixir_reft, [:set, :protected])
    {:ok, {ps, rs}}
  end

  def handle_call({:spawn, pid, spec}, _from, {ps, rs}) do
    pcount = :ets.update_counter(ps, pid, {2, 1, @max, @max+1})

    reply = if pcount > @max do
      :ets.insert(ps, {pid, @max})
      {:error, :limit}
    else
      {p, r} = smonitor(spec)
      :ets.insert(rs, {r, pid, p})
      {:ok, p}
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

  def handle_cast({:remove, pid}, {ps, rs}) do
    :ets.delete(ps, pid)
    :ets.match(rs, {:"$1", pid, :"$2"}) |> Enum.each(&remove_ref(rs, &1))
    {:noreply, {ps, rs}}
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

  # Helpers

  defp smonitor({m, f, a}), do: spawn_monitor(m, f, a)
  defp smonitor(f), do: spawn_monitor(f)

  defp remove_ref(tid, [ref, pid]) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
    :ets.delete(tid, ref)
  end
  defp remove_ref(_tid, _rp), do: :ok
end
