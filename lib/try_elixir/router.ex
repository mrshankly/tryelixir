defmodule TryElixir.Router do
  @moduledoc false

  use Plug.Router
  use Plug.ErrorHandler
  import Plug.Conn

  require Logger

  @sandbox_key "_tryelixir_sandbox"

  plug(Plug.Static, at: "/static", from: :try_elixir)

  plug(Plug.Session,
    store: :cookie,
    key: @sandbox_key,
    secure: true,
    secret_key_base: Application.fetch_env!(:try_elixir, :secret_key_base),
    encryption_salt: Application.fetch_env!(:try_elixir, :encryption_salt),
    signing_salt: Application.fetch_env!(:try_elixir, :signing_salt),
    same_site: "Lax"
  )

  plug(Plug.Parsers, parsers: [:urlencoded], pass: ["application/*"], validate_utf8: true)

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> fetch_session()
    |> put_session(@sandbox_key, nil)
    |> put_resp_content_type("text/html")
    |> send_resp(200, TryElixir.Template.index())
  end

  get "/about" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, TryElixir.Template.about())
  end

  get "/api/version" do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, System.version())
  end

  post "/api/eval" do
    conn = fetch_session(conn)
    pid = get_session(conn, @sandbox_key)

    {conn, pid} =
      if not is_pid(pid) or not Process.alive?(pid) do
        {:ok, pid} = TryElixir.Sandbox.start()
        {put_session(conn, @sandbox_key, pid), pid}
      else
        {conn, pid}
      end

    code = Map.fetch!(conn.params, "code")
    response = TryElixir.Sandbox.eval(pid, code)

    if response == :timeout do
      Logger.warn("router: eval call to #{inspect(pid)} timed out: #{inspect(code)}")
    end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, format_response(response))
  end

  match _ do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    Logger.error("Router error(#{kind}): #{reason}")

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(conn.status, "Something went wrong")
  end

  defp format_response({{:ok, term}, warnings, line}) do
    response = %{
      result: "#{inspect(term)}",
      prompt: "iex(#{line})> ",
      warnings: Enum.map(warnings, &elem(&1, 2))
    }

    Jason.encode!(response, escape: :javascript_safe)
  end

  defp format_response({{:error, error}, warnings, line}) do
    response = %{
      error: "#{error}",
      prompt: "iex(#{line})> ",
      warnings: Enum.map(warnings, &elem(&1, 2))
    }

    Jason.encode!(response, escape: :javascript_safe)
  end

  defp format_response({:incomplete, _warnings, line}) do
    Jason.encode!(%{prompt: "...(#{line})> "})
  end

  defp format_response(:timeout) do
    response = %{
      error: "timeout: code evaluation took too long",
      prompt: "iex(1)> "
    }

    Jason.encode!(response)
  end
end
