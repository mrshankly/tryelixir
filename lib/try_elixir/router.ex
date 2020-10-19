defmodule TryElixir.Router do
  @moduledoc false

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn

  require Logger

  @cookie_key "_tryelixir_session"

  plug(Plug.Static, at: "/static", from: :try_elixir)

  plug(Plug.Session,
    store: :cookie,
    key: @cookie_key,
    secret_key_base: Application.fetch_env!(:try_elixir, :secret_key_base),
    encryption_salt: Application.fetch_env!(:try_elixir, :encryption_salt),
    signing_salt: Application.fetch_env!(:try_elixir, :signing_salt)
  )

  plug(Plug.Parsers, parsers: [:urlencoded], pass: ["application/*"], validate_utf8: true)

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> fetch_session()
    |> put_session(@cookie_key, nil)
    |> send_resp(200, TryElixir.Template.index())
  end

  get "/about" do
    send_resp(conn, 200, TryElixir.Template.about())
  end

  get "/api/version" do
    send_resp(conn, 200, System.version())
  end

  post "/api/eval" do
    conn = fetch_session(conn)
    pid = get_session(conn, @cookie_key)

    {conn, pid} =
      if not is_pid(pid) or not Process.alive?(pid) do
        {:ok, pid} = TryElixir.Sandbox.start()
        {put_session(conn, @cookie_key, pid), pid}
      else
        {conn, pid}
      end

    code = Map.fetch!(conn.params, "code")
    response = TryElixir.Sandbox.eval(pid, code)

    send_resp(conn, 200, format_response(response))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    Logger.error("Router error(#{kind}): #{reason}")
    send_resp(conn, conn.status, "Something went wrong")
  end

  defp format_response({:incomplete, line}) do
    Jason.encode!(%{prompt: "...(#{line})> "})
  end

  defp format_response({{:ok, term}, line}) do
    response = %{
      type: "ok",
      result: "#{inspect(term)}",
      prompt: "iex(#{line})> "
    }

    Jason.encode!(response, escape: :javascript_safe)
  end

  defp format_response({{:error, error}, line}) do
    response = %{
      type: "ok",
      result: "#{error}",
      prompt: "iex(#{line})> "
    }

    Jason.encode!(response, escape: :javascript_safe)
  end
end
