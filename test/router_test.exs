defmodule RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts TryElixir.Router.init([])

  defp get(path) do
    TryElixir.Router.call(conn(:get, path), @opts)
  end

  test "root starts sandbox" do
    conn = Plug.Conn.fetch_session(get("/"))
    assert conn.status == 200

    sandbox = Plug.Conn.get_session(conn, "_tryelixir_session")
    assert is_pid(sandbox)
    assert Process.alive?(sandbox)
  end

  test "about returns OK" do
    conn = get("/about")
    assert conn.status == 200
  end

  test "api version" do
    conn = get("/api/version")
    assert conn.status == 200
    assert conn.resp_body == System.version()
  end
end
