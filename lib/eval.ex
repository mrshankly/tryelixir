defmodule Tryelixir.Eval do
  @moduledoc """
  Eval module for tryelixir, most of the code is the same as IEx.Server
  """
  @allowed_non_local HashDict.new [
    {Bitwise,  :all},
    {Dict,     :all},
    {Enum,     :all},
    {HashDict, :all},
    {Keyword,  :all},
    {List,     :all},
    {ListDict, :all},
    {Regex,    :all},
    {String,   :all},
    {Kernel,   [:access]}
  ]

  @iex_helpers_r [:c, :ls, :cd, :flush, :l, :m, :pwd, :r, :import_file]
  @iex_helpers_a [:h, :s, :t, :v]
  @allowed_local [:&&, :.., :<>, :@, :access, :and, :atom_to_binary, :binary_to_atom,
    :binary_to_existing_atom, :case, :cond, :div, :elem, :if, :in, :insert_elem,
    :is_exception, :is_range, :is_record, :is_record, :is_regex, :match?, :nil?,
    :or, :rem, :set_elem, :sigil_B, :sigil_C, :sigil_R, :sigil_W, :sigil_b,
    :sigil_c, :sigil_r, :sigil_w, :to_binary, :to_char_list, :try, :unless, :use,
    :xor, :|>, :||, :!, :!=, :!==, :*, :+, :+, :++, :-, :--, :/, :<, :<=, :=, :==,
    :===, :=~, :>, :>=, :abs, :atom_to_binary, :atom_to_list, :binary_part,
    :binary_to_atom, :binary_to_existing_atom, :binary_to_float, :binary_to_integer,
    :binary_to_integer, :binary_to_list, :binary_to_list, :binary_to_term, :bit_size,
    :bitstring_to_list, :byte_size, :float, :float_to_binary, :float_to_list, :hd,
    :inspect, :integer_to_binary, :integer_to_list, :iolist_size, :iolist_to_binary,
    :is_atom, :is_binary, :is_bitstring, :is_boolean, :is_float, :is_function,
    :is_integer, :is_list, :is_number, :is_pid, :is_port, :is_reference, :is_tuple,
    :length, :list_to_atom, :list_to_binary, :list_to_bitstring, :list_to_existing_atom,
    :list_to_float, :list_to_integer, :list_to_tuple, :max, :min, :not,
    :raise, :raise, :raise, :round, :size, :term_to_binary, :throw, :tl,
    :trunc, :tuple_size, :tuple_to_list, :fn, :->, :&]

  @doc """
  Eval loop for a tryelixir session. It does the following:

    * read input
    * check if the code being evaluated is allowed
    * trap exceptions in the code being evaluated
    * keep expression history
  """
  def start() do
    # TODO: handle history

    config = IEx.boot_config []
    { _, _, scope } = :elixir.eval('require IEx.Helpers', [], 0, config.scope)
    config = config.scope(scope)

    IO.puts "Interactive Elixir (#{System.version}) - (type h() ENTER for help)"
    eval_loop(config)
  end

  defp eval_loop(config) do
    counter = config.counter
    code    = config.cache
    line    = io_get(config)

    unless line == :eof do
      new_config =
        try do
          eval(code, line, counter, config)
        rescue
          exception ->
            print_exception(exception)
            config.cache('')
        catch
          kind, error ->
            print_error(kind, error)
            config.cache('')
        end

      eval_loop(new_config)
    end
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
  @break_trigger '#iex:break\n'
  defp eval(_, @break_trigger, _, config=IEx.Config[cache: '']) do
    # do nothing
    config
  end

  defp eval(_, @break_trigger, line_no, _) do
    :elixir_errors.parse_error(line_no, "iex", 'incomplete expression', [])
  end

  defp eval(code_so_far, latest_input, line_no, config) do
    code = code_so_far ++ latest_input
    case :elixir_translator.forms(code, line_no, "iex", []) do
      { :ok, forms } ->
        if is_safe?(forms) do
          { result, new_binding, scope } =
            :elixir.eval_forms(forms, config.binding, config.scope)

          io_put result

          config = config.cache(code).scope(nil).result(result)
          config.update_counter(&1+1).cache('').binding(new_binding).scope(scope).result(nil)
        else
          raise "restricted"
        end

      { :error, { line_no, error, token } } ->
        if token == [] do
          # Update config.cache in order to keep adding new input to
          # the unfinished expression in `code`
          config.cache(code)
        else
          # Encountered malformed expression
          :elixir_errors.parse_error(line_no, "iex", error, token)
        end
    end
  end

  # Check if the AST contains non allowed code, returns false if it does,
  # true otherwise.

  # check modules
  defp is_safe?({{:., _, [module, fun]}, _, args}) do
    module = Macro.expand(module, __ENV__)
    case HashDict.get(@allowed_non_local, module) do
      :all ->
        is_safe?(args)
      lst when is_list(lst) ->
        (fun in lst) and is_safe?(args)
      nil ->
        false
    end
  end

  # check calls to anonymous functions, eg. f.()
  defp is_safe?({{:., _, f_args}, _, args}) do
    is_safe?(f_args) and is_safe?(args)
  end

  # used with :fn
  defp is_safe?([do: args]) do
    is_safe?(args)
  end

  # used with :'->'
  defp is_safe?({left, _, right}) when is_list(left) do
    is_safe?(left) and is_safe?(right)
  end

  # check local functions
  defp is_safe?({dot, _, nil}) do
    (! dot in @iex_helpers_r)
  end

  defp is_safe?({dot, _, args}) do
    (dot in @iex_helpers_a) or
    ((dot in @allowed_local) and is_safe?(args))
  end

  defp is_safe?(lst) when is_list(lst) do
    Enum.all?(lst, fn(x) -> is_safe?(x) end)
  end

  defp is_safe?(_) do
    true
  end

  defp io_get(config) do
    prefix = if config.cache != [], do: "..."

    prompt = "#{prefix || "iex"}(#{config.counter})> "

    case IO.gets(:stdio, prompt) do
      :eof -> :eof
      { :error, _ } -> ''
      data -> :unicode.characters_to_list(data)
    end
  end

  defp io_put(result) do
    IO.puts "#{inspect result}"
  end

  defp print_exception(exception) do
    IO.puts "** (#{inspect exception.__record__(:name)}) #{exception.message}"
  end

  defp print_error(kind, reason) do
    IO.puts "** (#{kind}) #{inspect(reason)}"
  end
end
