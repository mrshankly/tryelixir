defmodule TryElixir.Template do
  @moduledoc false

  require EEx

  EEx.function_from_file(:def, :index, "lib/try_elixir/templates/index.eex")
  EEx.function_from_file(:def, :about, "lib/try_elixir/templates/about.eex")
end
