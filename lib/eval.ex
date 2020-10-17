defmodule TryElixir.Eval do
  @moduledoc """
  Eval module for tryelixir, based on IEx.Server
  """

  require Record

  @allowed_non_local Keyword.new [
    {Bitwise,      :all},
    {Dict,         :all},
    {Enum,         :all},
    {HashDict,     :all},
    {HashSet,      :all},
    {Keyword,      :all},
    {List,         :all},
    {ListDict,     :all},
    {Regex,        :all},
    {Set,          :all},
    {Stream,       :all},
    {String,       :all},
    {Integer,      :all},
    {Binary.Chars, [:to_binary]}, # string interpolation
    {Kernel,       [:access]},
    {System,       [:version]},
    {:calendar,    :all},
    {:math,        :all},
    {:os,          [:type, :version]}
  ]

  # with 0 arity
  @restricted_local [:binding, :is_alive, :make_ref, :node, :self]
  @allowed_local [:&&, :.., :<>, :access, :and, :atom_to_binary, :binary_to_atom,
    :case, :cond, :div, :elem, :if, :in, :insert_elem, :is_range, :is_record,
    :is_regex, :match?, :nil?, :or, :rem, :set_elem, :sigil_B, :sigil_C, :sigil_R,
    :sigil_W, :sigil_b, :sigil_c, :sigil_r, :sigil_w, :to_binary, :to_char_list,
    :unless, :xor, :|>, :||, :!, :!=, :!==, :*, :+, :+, :++, :-, :--, :/, :<, :<=,
    :=, :==, :===, :=~, :>, :>=, :abs, :atom_to_binary, :atom_to_list, :binary_part,
    :binary_to_atom, :binary_to_float, :binary_to_integer, :binary_to_integer,
    :binary_to_term, :bit_size, :bitstring_to_list, :byte_size,
    :float, :float_to_binary, :float_to_list, :hd, :inspect, :integer_to_binary,
    :integer_to_list, :iolist_size, :iolist_to_binary, :is_atom, :is_binary,
    :is_bitstring, :is_boolean, :is_float, :is_function, :is_integer, :is_list,
    :is_number, :is_tuple, :length, :list_to_atom, :list_to_bitstring,
    :list_to_float, :list_to_integer, :list_to_tuple, :max, :min, :not, :round, :size,
    :term_to_binary, :throw, :tl, :trunc, :tuple_size, :tuple_to_list, :fn, :->, :&,
    :__block__, :"{}", :"<<>>", :::, :lc, :inlist, :bc, :inbits, :^, :when, :|,
    :defmodule, :def, :defp, :__aliases__]

  Record.defrecord :config, counter: 1, binding: [], cache: '', scope: nil, env: nil,
    result: nil

  @doc """
  Starts a new process of eval_loop. It does the following:

    * read input
    * check if the code being evaluated is allowed
    * trap exceptions in the code being evaluated
  """
  def start do
    env    = :elixir.env_for_eval(file: "iex", delegate_locals_to: nil)
    scope  = :elixir_env.env_to_scope(env)
    config = config(scope: scope, env: env)
    spawn(fn -> eval_loop(config) end)
  end

  defp eval_loop(config) do
    receive do
      {from, {:input, line}} ->
        new_config = try do
          counter = config.counter
          code    = config.cache
          eval(code, :unicode.characters_to_list(line), counter, config)
        rescue
          exception ->
            config = config.cache('')
            config.result({"error", format_exception(exception)})
        catch
          kind, error ->
            config = config.cache('')
            config.result({"error", format_error(kind, error)})
        end
        prompt = new_prompt(new_config)
        send(from, {prompt, new_config.result})
        eval_loop(new_config.result(nil))
      :exit ->
        :ok
    after
      # kill the process after 5 minutes of idle
      300000 ->
        :ok
    end
  end

  defp new_prompt(config) do
    prefix = if config.cache != '', do: "..."
    "#{prefix || "iex"}(#{config.counter})> "
  end

  # The expression is parsed to see if it's well formed.
  # If parsing succeeds the AST is checked to see if the code is allowed,
  # if it is, the AST is evaluated.
  #
  # If parsing fails, this might be a TokenMissingError which we treat in
  # a special way (to allow for continuation of an expression on the next
  # line in the `eval_loop`). In case of any other error, we let :elixir_translator
  # to re-raise it.
  #
  # Returns updated config.
  defp eval(code_so_far, latest_input, line, config) do
    code = code_so_far ++ latest_input
    case Code.string_to_quoted(code, [line: line, file: "iex"]) do
      { :ok, forms } ->
        unless is_safe?(forms, [], config) do
          raise "restricted"
        end

        {result, new_binding, env, scope} =
          :elixir.eval_forms(forms, config.binding, config.env, config.scope)

        config = config.counter(line + 1).cache('').binding(new_binding)
        config.result({"ok", result}).scope(scope).env(env)

      { :error, { line, error, token } } ->
        if token == [] do
          # Update config.cache in order to keep adding new input to
          # the unfinished expression in `code`
          config.cache(code ++ '\n')
        else
          # Encountered malformed expression
          :elixir_errors.parse_error(line, "iex", error, token)
        end
    end
  end

  # Check if the AST contains non allowed code, returns false if it does,
  # true otherwise.
  #
  # check modules
  defp is_safe?({{:., _, [module, fun]}, _, args}, funl, config) do
    module = Macro.expand(module, __ENV__)
    case Keyword.get(@allowed_non_local, module) do
      :all ->
        is_safe?(args, funl, config)
      lst when is_list(lst) ->
        (fun in lst) and is_safe?(args, funl, config)
      _ ->
        if module in elem(config.env, 11) do
          is_safe?(args, funl, config)
        else
          false
        end
    end
  end

  # check calls to anonymous functions, eg. f.()
  defp is_safe?({{:., _, f_args}, _, args}, funl, config) do
    is_safe?(f_args, funl, config) and is_safe?(args, funl, config)
  end

  # used with :fn
  defp is_safe?([do: args], funl, config) do
    is_safe?(args, funl, config)
  end

  # used with :'->'
  defp is_safe?({left, _, right}, funl, config) when is_list(left) do
    is_safe?(left, funl, config) and is_safe?(right, funl, config)
  end

  # limit range size
  defp is_safe?({:.., _, [begin, last]}, _, _) do
    (last - begin) <= 100 and last < 1000
  end

  # don't size and unit in :::
  defp is_safe?({:::, _, [_, opts]}, _, _) do
    do_opts(opts)
  end

  # allow functions inside the module to be called on that module as locals
  defp is_safe?({:defmodule, _, args}, _, config) do
    is_safe?(args, get_mod_funs(args), config)
  end

  # check functions defined with Kernel.def/2
  defp is_safe?({fun, _, [header, args]}, funl, config) when fun == :def or fun == :defp do
    case header do
      {:when, _, [_|rest]} ->
        is_safe?(rest, funl, config) and is_safe?(args, funl, config)
      _ ->
        is_safe?(args, funl, config)
    end
  end

  # check 0 arity local functions
  defp is_safe?({dot, _, nil}, funl, _) when is_atom(dot) do
    (dot in funl) or (not dot in @restricted_local)
  end

  defp is_safe?({dot, _, args}, funl, config) do
    ((dot in funl) or (dot in @allowed_local)) and is_safe?(args, funl, config)
  end

  defp is_safe?(lst, funl, config) when is_list(lst) do
    if length(lst) <= 100 do
      Enum.all?(lst, fn(x) -> is_safe?(x, funl, config) end)
    else
      false
    end
  end

  defp is_safe?(_, _, _) do
    true
  end

  defp do_opts(opt) when is_tuple(opt) do
    case opt do
      {:size, _, _} -> false
      {:unit, _, _} -> false
      _ -> true
    end
  end

  defp do_opts([h|t]) do
    case h do
      {:size, _, _} -> false
      {:unit, _, _} -> false
      _ -> do_opts(t)
    end
  end

  defp do_opts([]), do: true

  # gets the list of defined functions (non-private and private) in a module
  defp get_mod_funs([_, [do: {:__block__, _, funs}]]) do
    get_funs(funs, [])
  end

  defp get_mod_funs([_, [do: fun]]) do
    get_funs([fun], [])
  end

  defp get_mod_funs(_other) do
    false
  end

  defp get_funs([], funs), do: funs

  defp get_funs([{d, _, args} | t], acc) when d == :def or d == :defp do
    case args do
      [{:when, _, [{fun, _, _} | _]} | _] ->
        get_funs(t, [fun | acc])
      [{fun, _, _} | _] ->
        get_funs(t, [fun | acc])
      _ ->
        get_funs(t, acc)
    end
  end

  defp get_funs([_ | t], acc), do: get_funs(t, acc)

  defp format_exception(exception) do
    "** (#{inspect exception.__record__(:name)}) #{exception.message}"
  end

  defp format_error(kind, reason) do
    "** (#{kind}) #{inspect(reason)}"
  end
end
