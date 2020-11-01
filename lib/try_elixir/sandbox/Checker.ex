defmodule TryElixir.SandboxError do
  defexception message: "forbidden code"
end

defmodule TryElixir.Sandbox.Checker do
  @moduledoc false

  require Logger

  alias TryElixir.SandboxError

  # Functions handled specifically by safe!/3 should not be added to this list.
  # This is so that in cases where the pattern is not exactly matched by safe!/3,
  # the function will not be allowed to run. Thus, avoiding potentially dangerous
  # code to be evaluated.
  #
  # Examples: :defmodule, :., :.., :"::".
  @allowed_local_functions [
    :if,
    :fn,
    :self,
    :+,
    :*,
    :-,
    :++,
    :--,
    :/,
    :<<>>,
    :=,
    :div,
    :|,
    :{},
    :is_binary,
    :is_list,
    :elem,
    :put_elem,
    :==,
    :===,
    :^,
    :<>,
    :fn,
    :->,
    :when,
    :>,
    :def,
    :defp,
    :__aliases__,
    :__block__,
    :&
  ]

  @allowed_named_functions %{
    :math => :all,
    Access => :all,
    Atom => :all,
    Base => :all,
    Bitwise => :all,
    Calendar => :all,
    Calendar.ISO => :all,
    Date => :all,
    DateTime => :all,
    Enum => :all,
    Float => :all,
    Function => [:identity, :info],
    Integer => :all,
    Keyword => :all,
    List => :all,
    Map => :all,
    MapSet => :all,
    NaiveDateTime => :all,
    OptionParser => :all,
    Range => [:disjoint?],
    Regex => :all,
    Stream => :all,
    String => :all,
    System => [:endianness, :otp_release, :version],
    Time => :all,
    Tuple => :all,
    URI => [
      :char_reserved?,
      :char_unescaped?,
      :char_unreserved?,
      :decode,
      :decode_query,
      :decode_www_form,
      :encode,
      :encode_query,
      :encode_www_form,
      :merge,
      :parse,
      :query_decoder,
      :to_string
    ],
    Version => :all,
    Kernel => @allowed_local_functions
  }

  @max_collection_length 100
  @max_binary_size_value 128
  @max_binary_unit_value 16

  @doc """
  Checks if the AST contains forbidden code. Returns a safe quoted form,
  or raises a `SandboxError` exception if `quoted` is not safe to evaluate.
  """
  @spec safe!(Macro.t(), Macro.Env.t()) :: Macro.t()
  def safe!(quoted, env \\ __ENV__) do
    safe!(quoted, env, [])
  end

  # Before checking if the module is safe, we need to gather all the public
  # and private functions defined by the module. These functions are passed
  # to safe!/3 as the `locals` parameter. Doing this allows the user to call
  # functions defined by the module, inside that module.
  @spec safe!(Macro.t(), Macro.Env.t(), [atom]) :: Macro.t()
  defp safe!(quoted = {:defmodule, _, module = [_alias, [do: {:__block__, _, defs}]]}, env, _) do
    safe!(module, env, module_locals(defs))
    quoted
  end

  defp safe!(quoted = {:defmodule, _, module = [_alias, [do: definition]]}, env, _) do
    safe!(module, env, module_locals([definition]))
    quoted
  end

  # Named function call.
  defp safe!(quoted = {{:., _, [module, fun]}, _, args}, env, locals) do
    module = Macro.expand(module, env)

    functions =
      if module in env.context_modules do
        :all
      else
        Map.get(@allowed_named_functions, module, [])
      end

    if is_list(functions) and fun not in functions do
      raise SandboxError,
        message: "forbidden function #{Exception.format_mfa(module, fun, length(args))}"
    end

    safe!(args, env, locals)
    quoted
  end

  # Anonymous function call.
  defp safe!(quoted = {{:., _, lambda}, _, args}, env, locals) do
    safe!(lambda, env, locals)
    safe!(args, env, locals)
    quoted
  end

  # Limit the range span to `@max_collection_length`, this is so
  # users don't turn ranges with huge spans into huge lists.
  defp safe!(quoted = {:.., _, [first, last]}, _env, _locals)
       when is_integer(first) and is_integer(last) do
    if abs(last - first) > @max_collection_length do
      raise SandboxError,
        message: "range span is greater than the maximum allowed (#{@max_collection_length})"
    end

    quoted
  end

  # Forbidden any type of range where `first` and `last` are not
  # both integer literals.
  defp safe!({:.., _, _args}, _env, _locals) do
    raise SandboxError, "range limit is not an integer literal"
  end

  # Limit the values of `size` and `unit` in binaries.
  defp safe!(quoted = {:"::", _, args}, _env, _locals) do
    Enum.each(args, &check_bitstring_opts!/1)
    quoted
  end

  # Leaf nodes, like variables.
  defp safe!(quoted = {leaf, _, nil}, _env, _locals) when is_atom(leaf) do
    quoted
  end

  # Local and imported function calls.
  defp safe!(quoted = {fun, _, args}, env, locals) when is_atom(fun) do
    if fun not in locals and fun not in @allowed_local_functions do
      raise SandboxError, message: "forbidden function #{fun}/#{length(args)}"
    end

    safe!(args, env, locals)
    quoted
  end

  defp safe!(quoted = {node, _, children}, env, locals) do
    safe!(node, env, locals)
    safe!(children, env, locals)
    quoted
  end

  # Keywords.
  defp safe!(keyword = {key, value}, env, locals) when is_atom(key) do
    safe!(value, env, locals)
    keyword
  end

  defp safe!(nodes, env, locals) when is_list(nodes) do
    check_length!(nodes)
    Enum.each(nodes, &safe!(&1, env, locals))
    nodes
  end

  defp safe!(node, _env, _locals), do: node

  # Raises a `SandboxError` exception when `list` has
  # more than `@max_collection_length` elements.
  defp check_length!(list) when is_list(list) do
    check_length!(list, 0)
    list
  end

  defp check_length!(_, length) when length > @max_collection_length do
    raise SandboxError,
      message: "collection length is greater than the maximum allowed (#{@max_collection_length})"
  end

  defp check_length!([], length), do: length

  defp check_length!([_head | tail], length) do
    check_length!(tail, length + 1)
  end

  # Raises a `SandboxError` exception when the values
  # of `:size` or `:unit` are too big.
  defp check_bitstring_opts!({:size, _, [n]}) when n > @max_binary_size_value do
    raise SandboxError,
      message:
        "size value in bitstring is greater than the maximum allowed (#{@max_binary_size_value})"
  end

  defp check_bitstring_opts!({:unit, _, [n]}) when n > @max_binary_unit_value do
    raise SandboxError,
      message:
        "unit value in bitstring is greater than the maximum allowed (#{@max_binary_unit_value})"
  end

  # Multiple binary options can be separated by the `-` operator,
  # check those cases too.
  defp check_bitstring_opts!({:-, _, args}) when is_list(args) do
    Enum.each(args, &check_bitstring_opts!/1)
  end

  defp check_bitstring_opts!(opt), do: opt

  defp module_locals(definitions) when is_list(definitions) do
    gather_locals = fn
      {:def, _, [{:when, _, [{local, _, _} | _]} | _]}, acc -> [local | acc]
      {:def, _, [{local, _, _} | _]}, acc -> [local | acc]
      {:defp, _, [{:when, _, [{local, _, _} | _]} | _]}, acc -> [local | acc]
      {:defp, _, [{local, _, _} | _]}, acc -> [local | acc]
      _, acc -> acc
    end

    Enum.reduce(definitions, [], gather_locals)
  end
end
