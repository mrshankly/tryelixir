defmodule ApiRouter do
  use Dynamo.Router

  prepare do
    conn.fetch [:cookies, :params]
  end

  post "/eval" do
  	pid = Dynamo.HTTP.Cookies.get_cookie(conn, :eval_pid)
  	|> Tryelixir.Cookie.decode |> list_to_pid

  	pid <- {self, {:input, conn.params[:code]}}
  	resp = receive do
  		response ->
  			response
  	end

    conn.resp(200, format_json(resp))
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
