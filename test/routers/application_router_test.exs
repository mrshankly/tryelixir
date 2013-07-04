Code.require_file "../../test_helper.exs", __FILE__

defmodule ApplicationRouterTest do
  use Tryelixir.TestCase
  use Dynamo.HTTP.Case

  # Sometimes it may be convenient to test a specific
  # aspect of a router in isolation. For such, we just
  # need to set the @endpoint to the router under test.
  @endpoint ApplicationRouter

  test "returns OK" do
    conn = get("/")
    assert conn.status == 200
  end
end
