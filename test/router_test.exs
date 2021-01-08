defmodule RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias TryElixir.Router

  @opts Router.init([])

  defp get(path) do
    Router.call(conn(:get, path), @opts)
  end

  defp post(path, params) do
    Router.call(conn(:post, path, params), @opts)
  end

  defp post(conn, path, params) do
    Router.call(recycle_cookies(conn(:post, path, params), conn), @opts)
  end

  test "root returns OK and clears session" do
    conn = Plug.Conn.fetch_session(get("/"))
    assert conn.status == 200

    sandbox = Plug.Conn.get_session(conn, "_tryelixir_session")
    assert sandbox == nil
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

  test "api eval complete expression" do
    conn = post("/api/eval", code: "21 * 2")
    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    refute Map.has_key?(body, "error")
    assert Map.fetch!(body, "result") == "42"
    assert Map.fetch!(body, "prompt") == "iex(2)> "
  end

  test "api eval incomplete expression" do
    conn = post("/api/eval", code: "3 + ")
    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    refute Map.has_key?(body, "error")
    refute Map.has_key?(body, "result")
    assert Map.fetch!(body, "prompt") == "...(1)> "

    conn = post(conn, "/api/eval", code: "1")
    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    refute Map.has_key?(body, "error")
    assert Map.fetch!(body, "result") == "4"
    assert Map.fetch!(body, "prompt") == "iex(2)> "
  end
end
