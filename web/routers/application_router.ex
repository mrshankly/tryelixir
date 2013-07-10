defmodule ApplicationRouter do
  use Dynamo.Router

  forward "/api", to: ApiRouter

  get "/" do
    cookie = Tryelixir.Eval.start |> pid_to_list |> Tryelixir.Cookie.encode
    conn = Dynamo.HTTP.Cookies.put_cookie(conn, :eval_pid, cookie)
    conn = conn.assign(:version, System.version)
    render conn, "index.html"
  end

  get "/about" do
    render conn, "about.html"
  end

  get "/*" do
    conn.resp(404, "404")
  end
end
