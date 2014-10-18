defmodule PermissionError do
  defexception file: nil, line: nil, description: "restricted code"

  @spec message(Exception.t) :: String.t
  def message(exception) do
    file = Exception.format_file_line(exception.file, exception.line)
    "#{file} #{exception.description}"
  end
end

defmodule Tryelixir.Repl.Sandbox do
  @moduledoc """
  Responsible for sandboxing and evaluating elixir code.
  """

  alias Tryelixir.Repl.Config

  @type result :: {:ok, term} | {:error, String.t} | :incomplete

  @break '#iex:break\n'

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

  Returns a 2 element tuple, `{result, new_config}`, where `result` can be one
  of the following, `{:ok, term}`, `{:error, error_message}` and `:incomplete`.
  """
  @spec eval(String.t, Config.t) :: {result, Config.t}
  def eval(code, config) do
    try do
      do_eval(String.to_char_list(code), config)
    catch
      kind, error ->
        {{:error, fmt_error(kind, error)}, %{config | cache: ''}}
    end
  end

  defp do_eval(@break, config = %Config{cache: ''}) do
    {{:ok, ""}, config}
  end

  defp do_eval(@break, config) do
    raise TokenMissingError, file: "iex", line: config.counter
  end

  defp do_eval(input, config) do
    code = config.cache ++ input
    form = Code.string_to_quoted(code, [file: "iex", line: config.counter])
    do_eval(form, code, config)
  end

  defp do_eval({:ok, form}, _code, config) do
    {result, binding, env, scope} =
      :elixir.eval_forms(form, config.binding, config.env, config.scope)

    new_config = %{config | binding: binding,
                            cache: '',
                            counter: config.counter + 1,
                            env: env,
                            scope: scope}
    {{:ok, result}, new_config}
  end

  defp do_eval({:error, {_, _, ""}}, code, config) do
    {:incomplete, %{config | cache: code}}
  end

  defp do_eval({:error, {line, error, token}}, _code, _config) do
    :elixir_errors.parse_error(line, "iex", error, token)
  end

  defp fmt_error(kind, error) do
    Exception.format_banner(kind, error)
  end
end
