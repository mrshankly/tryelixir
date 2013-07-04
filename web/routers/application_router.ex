defmodule ApplicationRouter do
  use Dynamo.Router

  forward "/api", to: ApiRouter

  get "/" do
    render conn, "index.html"
  end

  get "/about" do
    render conn, "about.html"
  end
end
