Dynamo.under_test(Tryelixir.Dynamo)
Dynamo.Loader.enable
ExUnit.start

defmodule Tryelixir.TestCase do
  use ExUnit.CaseTemplate

  # Enable code reloading on test cases
  setup do
    Dynamo.Loader.enable
    :ok
  end
end
