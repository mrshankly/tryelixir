defmodule ApplicationRouter do
  use Dynamo.Router

  forward "/api", to: ApiRouter

  get "/" do
  	cookie = Tryelixir.Eval.start
  	|> pid_to_list |> Tryelixir.Cookie.encode
  	conn = Dynamo.HTTP.Cookies.put_cookie(conn, :eval_pid, cookie)
    render conn, "index.html"
  end

  get "/about" do
    render conn, "about.html"
  end
end
