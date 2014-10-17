defmodule Tryelixir.Repl.Sandbox do
  @moduledoc """
  Responsible for sandboxing and evaluating the elixir code.
  """

  alias Tryelixir.Repl.Config

  @doc """
  The first step is parsing the AST to check for allowed and disallowed
  code (module, functions, operators, etc) and correctness. If the check
  succeeds the AST is evaluated.

  The AST check might fail for the following reasons:

    * Disallowed code found, in which case the AST is not evaluted and the
      config cache is cleared.

    * Incomplete code (TokenMissingError) which we handle the same as iex,
      ask for the rest of the code.

    * Incorrect code, the AST is not evaluated and the config cache is cleared.

  Returns a 2 element tuple, `{result | error_message, new_config}`.
  """
  @spec eval(String.t, Config.t) :: {String.t, Config.t}
  def eval(code, config) do
    try do
      do_eval(String.to_char_list(code), config)
    catch
      _kind, _error ->
        {:error, %{config | cache: ''}}
    end
  end

  defp do_eval(input, config) do
    _code = config.cache ++ input
    {:ok, config}
  end
end
