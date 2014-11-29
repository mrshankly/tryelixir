defmodule Tryelixir.PermissionError do
  defexception message: "restricted code"

  @spec exception(String.t) :: Exception.t
  def exception(msg) when is_binary(msg) do
    %Tryelixir.PermissionError{message: msg}
  end
end

defmodule Tryelixir.Repl.Sandbox do
  @moduledoc """
  Responsible for sandboxing and evaluating elixir code.
  """

  alias Tryelixir.Repl.Config

  @type result :: {:ok, term} | {:error, String.t} | :incomplete

  @break '#iex:break\n'

  @locals [
    # Kernel
    :!, :!=, :!==, :&&, :*, :+, :++, :-, :--, :.., :"//", :<, :<=, :<>, :==,
    :===, :=~, :>, :>=, :@, :abs, :and, :binding, :binary_part, :bit_size,
    :byte_size, :def, :defmodule, :defp, :defstruct, :destructure, :div, :elem,
    :get_in, :get_and_update_in, :hd, :if, :in, :inspect, :is_atom, :is_binary,
    :is_bitstring, :is_boolean, :is_float, :is_function, :is_integer, :is_list,
    :is_map, :is_nil, :is_number, :is_pid, :is_tuple, :length, :map_size,
    :match?, :max, :min, :not, :or, :put_elem, :put_in, :raise, :rem, :reraise,
    :round, :self, :send, :sigil_C, :sigil_R, :sigil_S, :sigil_W, :sigil_c,
    :sigil_r, :sigil_s, :sigil_w, :spawn, :struct, :throw, :tl, :to_char_list,
    :to_string, :trunc, :tuple_size, :unless, :update_in, :|>, :||,
    # Kernel.SpecialForms
    :%, :%{}, :&, :., :<<>>, :^, :__aliases__, :__block__, :case, :cond, :fn,
    :->, :for, :receive, :try, :when, :{}, :=
  ]

  @non_locals [
    {Access, :all}, {Enum, :all}, {List, :all}
  ]

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
        {{:error, format_err(kind, error)}, %{config | cache: '', mod_locals: []}}
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
    config = safe!(form, config)

    {result, binding, env, scope} =
      :elixir.eval_forms(form, config.binding, config.env, config.scope)

    new_config = %{config | binding: binding,
                            cache: '',
                            counter: config.counter + 1,
                            env: env,
                            scope: scope,
                            mod_locals: []}
    {{:ok, format_result(result)}, new_config}
  end

  defp do_eval({:error, {_, _, ""}}, code, config) do
    {:incomplete, %{config | cache: code}}
  end

  defp do_eval({:error, {line, error, token}}, _code, _config) do
    :elixir_errors.parse_error(line, "iex", error, token)
  end

  # safe!/2, this function parses the AST and checks for anything that is not
  # allowed to run. Returns a new config. If anything is not ok, an error is
  # raised.

  # Non-locals (eg. Module.function(arg)).
  defp safe!({{:., _, [module, fun]}, _, args}, config) do
    module = Macro.expand(module, config.env)
    if is_atom(module) do
      case @non_locals[module] do
        :all ->
          safe!(args, config)
        fs when is_list(fs) ->
          if fun in fs do
            safe!(args, config)
          else
            raise Tryelixir.PermissionError,
              "restricted function #{format_fn(module, fun, args)}"
          end
        nil ->
          if first_mod(module) in config.env.context_modules do
            safe!(args, config)
          else
            raise Tryelixir.PermissionError,
              "restricted function #{format_fn(module, fun, args)}"
          end
      end
    else
      safe!(args, config)
    end
  end

  # Anonymous function.
  defp safe!({{:., _, [{_, _, nil}]}, _, args}, config) do
    safe!(args, config)
  end

  # Limit range width to 100.
  defp safe!({:.., _, args = [first, last]}, config) do
    case {expand_num(first), expand_num(last)} do
      {n, m} when is_integer(n) and is_integer(m) ->
        if abs(m - n) <= 100 do
          config
        else
          raise Tryelixir.PermissionError, "range is wider than 100"
        end
      _ ->
        safe!(args, config)
    end
  end

  # Ignore left side with the match operator, this is needed so we can defined
  # variables with names of functions that are not allowed.
  defp safe!({:=, _, [_left, right]}, config) do
    safe!(right, config)
  end

  # Allow redefinition of modules only in config.env.context_modules and
  # populate config.mod_locals.
  defp safe!({:defmodule, _, args = [module | _]}, config) do
    module = Macro.expand(module, config.env)
    if mod_defined?(module, config.env) do
      raise Tryelixir.PermissionError, "redefinition of module #{module} is not allowed"
    else
      locals = mod_locals(args) ++ config.mod_locals
      safe!(args, %{config | mod_locals: locals})
    end
  end

  # Allowed local.
  defp safe!({local, _, args}, config) when local in @locals do
    safe!(args, config)
  end

  # Variables and locals with arity 0.
  defp safe!({local, _, nil}, config) do
    bind = Keyword.has_key?(config.binding, local)
    special = local in [:make_ref, :node]

    # The order matters, first check if it's a bind and then check
    # if it's not a special case. This is so we can write stuff like this:
    #   node     #=> PermissionError
    #   node = 1 #=> 1
    #   node     #=> 1
    #   node()   #=> PermissionError
    if bind or not special do
      config
    else
      raise Tryelixir.PermissionError, "restricted function: #{format_fn(local, 0)}"
    end
  end

  # Local with arity > 0.
  defp safe!({local, _, args}, config) do
    special = local in [:make_ref, :node]

    if not special and local in config.mod_locals do
      safe!(args, config)
    else
      if local_defined?(config.env, local, args) do
        raise Tryelixir.PermissionError, "restricted function: #{format_fn(local, args)}"
      else
        raise RuntimeError, "undefined function: #{format_fn(local, args)}"
      end
    end
  end

  defp safe!([do: args], config) do
    safe!(args, config)
  end

  # Limit lists to 100 elements and check every element.
  defp safe!(list, config) when is_list(list) do
    if bigger_than_100(list) do
      raise Tryelixir.PermissionError, "list has more than 100 elements"
    else
      Enum.reduce(list, config, &safe!(&1, &2))
    end
  end

  defp safe!(_form, config) do
    config
  end

  # Helpers

  # Returns true if the given module is already defined and is not a user
  # defined module, false otherwise.
  defp mod_defined?(module, env) do
    :code.is_loaded(module) && not first_mod(module) in env.context_modules
  end

  # Check if a local (function or macro) is defined in env.
  defp local_defined?(env, local, nil) do
    local_defined?(env, local, 0)
  end

  defp local_defined?(env, local, args) when is_list(args) do
    local_defined?(env, local, length(args))
  end

  defp local_defined?(env, local, arity) do
    Enum.any?([env.functions, env.macros], fn(xs) ->
      Enum.any?(xs, fn({_, ls}) -> arity in Keyword.get_values(ls, local) end)
    end)
  end

  # Returns a list of every attribute and function defined in the module.
  defp mod_locals([_, [do: {:__block__, _, fs}]]) do
    do_mod_locals(fs, [])
  end

  defp mod_locals([_, [do: f]]) do
    do_mod_locals([f], [])
  end

  defp mod_locals(_other), do: []

  defp do_mod_locals([], acc), do: acc

  defp do_mod_locals([{d, _, arg} | fs], acc) when d in [:@, :def, :defp] do
    case arg do
      [{:when, _, [{f, _, _} | _]} | _] ->
        do_mod_locals(fs, [f|acc])
      [{f, _, _} | _] ->
        do_mod_locals(fs, [f|acc])
      _other ->
        do_mod_locals(fs, acc)
    end
  end

  defp do_mod_locals([_|fs], acc) do
    do_mod_locals(fs, acc)
  end

  # Returns the first name of a module:
  #   first_mod(Very.Long.Module) #=> :Elixir.Very
  defp first_mod(module) do
    first_mod(Atom.to_string(module), [])
  end

  defp first_mod(<<"Elixir.", c, s :: binary>>, acc) do
    first_mod(s, [c | acc])
  end

  defp first_mod(<<>>, acc) do
    'Elixir.' ++ Enum.reverse(acc) |> List.to_atom
  end

  defp first_mod(<<?., _ :: binary>>, acc) do
    'Elixir.' ++ Enum.reverse(acc) |> List.to_atom
  end

  defp first_mod(<<c, s :: binary>>, acc) do
    first_mod(s, [c | acc])
  end

  # Expand numbers with an explicit signal (eg. +12, -3).
  defp expand_num(n) when is_integer(n), do: n
  defp expand_num({:+, _, [n]}) when is_integer(n), do: +n
  defp expand_num({:-, _, [n]}) when is_integer(n), do: -n
  defp expand_num(other), do: other

  defp bigger_than_100(l), do: do_bigger(l, 0)
  defp do_bigger([], acc) when acc <= 100, do: false
  defp do_bigger(_l, 101), do: true
  defp do_bigger([_|xs], acc), do: do_bigger(xs, acc+1)

  # Format helpers. Makes results, functions and errors pretty.
  defp format_result(result) do
    inspect(result, [width: 80, pretty: true])
  end

  defp format_fn(function, args) when is_list(args) do
    "#{function}/#{length(args)}"
  end

  defp format_fn(function, nil) do
    "#{function}/0"
  end

  defp format_fn(function, arity) do
    "#{function}/#{arity}"
  end

  defp format_fn(module, function, args) when is_list(args) do
    Exception.format_mfa(module, function, length(args))
  end

  defp format_fn(module, function, nil) do
    Exception.format_mfa(module, function, 0)
  end

  defp format_fn(module, function, arity) do
    Exception.format_mfa(module, function, arity)
  end

  defp format_err(kind, error) do
    Exception.format_banner(kind, error)
  end
end
