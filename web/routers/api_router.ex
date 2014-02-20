defmodule ApiRouter do
  use Dynamo.Router

  prepare do
    conn.fetch [:cookies, :params]
  end

  get "/version" do
    conn.resp(200, System.version)
  end

  get "/*" do
    conn.resp(404, "404")
  end

  post "/eval" do
    {eval_pid, conn} =
      case Dynamo.HTTP.Cookies.get_cookie(conn, :eval_pid) do
        nil ->
          start_eval(conn)

        encoded_pid ->
          case Tryelixir.Cookie.decode(encoded_pid) do
            :error ->
              start_eval(conn)
            cookie ->
              pid = String.to_char_list!(cookie) |> :erlang.list_to_pid
              unless Process.alive? pid do
                start_eval(conn)
              else
                {pid, conn}
              end
          end
      end

    send(eval_pid, {self, {:input, conn.params[:code]}})
    resp = receive do
      response ->
        response
    after
      2000 ->
        Process.exit(eval_pid, :kill)
        {"iex> ", {"error", "timeout"}}
    end

    conn.resp(200, format_json(resp))
  end

  post "/*" do
    conn.resp(404, "404")
  end

  # Helpers.
  defp put_cookie(pid, conn) do
    cookie = :erlang.pid_to_list(pid) |> Tryelixir.Cookie.encode
    Dynamo.HTTP.Cookies.put_cookie(conn, :eval_pid, cookie)
  end

  defp start_eval(conn) do
    pid = Tryelixir.Eval.start
    conn = put_cookie(pid, conn)
    {pid, conn}
  end

  defp format_json({prompt, nil}) do
    ~s/{"prompt":"#{prompt}"}/
  end

  defp format_json({prompt, {"error", result}}) do
    result = Inspect.BitString.escape(result, ?")
    ~s/{"prompt":"#{prompt}","type":"error","result":"#{result}"}/
  end

  defp format_json({prompt, {type, result}}) do
    # show double-quotes in strings
    result = Inspect.BitString.escape(inspect(result), ?")
    ~s/{"prompt":"#{prompt}","type":"#{type}","result":"#{result}"}/
  end
end
