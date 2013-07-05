Code.require_file "test_helper.exs", __DIR__

defmodule CookiesTest do
  use Tryelixir.Case

  test "Encode/Decode" do
    encoded = Tryelixir.Cookie.encode("test_cookie")
    assert Tryelixir.Cookie.decode(encoded) == "test_cookie"
  end
end