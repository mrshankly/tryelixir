Code.require_file "../../test_helper.exs", __ENV__.file

# Feature tests goes through the Dynamo.under_test
# and are meant to test the full stack.
defmodule HomeTest do
  use Tryelixir.TestCase
  use Dynamo.HTTP.Case

  test "returns OK" do
    conn = get("/")
    assert conn.status == 200
  end
end
