defmodule ApplicationRouter do
  use Dynamo.Router

  forward "/api", to: ApiRouter

  get "/" do
    conn = conn.assign(:version, System.version)
    render conn, "index.html"
  end

  get "/about" do
    render conn, "about.html"
  end
end
