defmodule TryElixir.Router do
  @moduledoc false

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn

  plug(Plug.Static, at: "/static", from: :try_elixir)

  plug(Plug.Session,
    store: :cookie,
    key: "_tryelixir_session",
    secret_key_base: Application.fetch_env!(:try_elixir, :secret_key_base),
    encryption_salt: Application.fetch_env!(:try_elixir, :encryption_salt),
    signing_salt: Application.fetch_env!(:try_elixir, :signing_salt)
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    pid = TryElixir.Eval.start()

    conn
    |> fetch_session()
    |> put_session("_tryelixir_session", pid)
    |> send_resp(200, TryElixir.Template.index())
  end

  get "/about" do
    send_resp(conn, 200, TryElixir.Template.about())
  end

  get "/api/version" do
    send_resp(conn, 200, System.version())
  end

  post "/api/eval" do
    send_resp(conn, 200, ~s/{"prompt": "iex(42)> "}/)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    # TODO log error
    send_resp(conn, conn.status, "Something went wrong")
  end
end
