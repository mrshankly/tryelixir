defmodule ApiRouter do
  use Dynamo.Router

  prepare do
    conn.fetch :params
  end

  post "/eval" do
    conn.resp(200, "#{conn.params[:code]}")
  end
end
