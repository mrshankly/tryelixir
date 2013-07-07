defmodule ApiRouter do
  use Dynamo.Router

  prepare do
    conn.fetch [:cookies, :params]
  end

  post "/eval" do
    pid = Dynamo.HTTP.Cookies.get_cookie(conn, :eval_pid)
    |> Tryelixir.Cookie.decode |> binary_to_list |> list_to_pid

    unless Process.alive? pid do
      pid = Tryelixir.Eval.start
      cookie = pid_to_list(pid) |> Tryelixir.Cookie.encode
      conn = Dynamo.HTTP.Cookies.put_cookie(conn, :eval_pid, cookie)
    end

    pid <- {self, {:input, conn.params[:code]}}
    resp = receive do
      response ->
        response
    after
      2000 ->
        Process.exit(pid, :kill)
        {"iex> ", {"error", "timeout"}}
    end

    conn.resp(200, format_json(resp))
  end

  defp format_json({prompt, nil}) do
    %b/{"prompt":"#{prompt}"}/
  end

  defp format_json({prompt, {"error", result}}) do
    %b/{"prompt":"#{prompt}","type":"error","result":"#{result}"}/
  end

  defp format_json({prompt, {type, result}}) do
    # show double-quotes in strings
    result = String.replace("#{inspect result}", "\"", "\\\"")
    %b/{"prompt":"#{prompt}","type":"#{type}","result":"#{result}"}/
  end
end
