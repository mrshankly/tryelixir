defmodule ApiRouter do
  use Dynamo.Router

  prepare do
    conn.fetch [:cookies, :params]
  end

  get "/version" do
    conn.resp(200, System.version)
  end

  post "/eval" do
    {eval_pid, conn} = case Dynamo.HTTP.Cookies.get_cookie(conn, :eval_pid) do
      nil ->
        pid = Tryelixir.Eval.start
        conn = put_cookie(pid, conn)
        {pid, conn}

      encoded_pid ->
        pid = Tryelixir.Cookie.decode(encoded_pid) |> binary_to_list |> list_to_pid

        unless Process.alive? pid do
          pid = Tryelixir.Eval.start
          conn = put_cookie(pid, conn)
        end

        {pid, conn}
    end

    eval_pid <- {self, {:input, conn.params[:code]}}
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

  defp put_cookie(pid, conn) do
    cookie = pid_to_list(pid) |> Tryelixir.Cookie.encode
    Dynamo.HTTP.Cookies.put_cookie(conn, :eval_pid, cookie)
  end

  defp format_json({prompt, nil}) do
    %b/{"prompt":"#{prompt}"}/
  end

  defp format_json({prompt, {"error", result}}) do
    result = String.escape "#{result}", ?"
    %b/{"prompt":"#{prompt}","type":"error","result":"#{result}"}/
  end

  defp format_json({prompt, {type, result}}) do
    # show double-quotes in strings
    result = String.escape "#{inspect result}", ?"
    %b/{"prompt":"#{prompt}","type":"#{type}","result":"#{result}"}/
  end
end
