defmodule TryElixir.Sandbox.Modules do
  @alphabet {
    ?a, ?b, ?c, ?d, ?e, ?f, ?g, ?h, ?i, ?j, ?k, ?l, ?m,
    ?n, ?o, ?p, ?q, ?r, ?s, ?t, ?u, ?v, ?w, ?x, ?y, ?z,
    ?A, ?B, ?C, ?D, ?E, ?F, ?G, ?H, ?I, ?J, ?K, ?L, ?M,
    ?N, ?O, ?P, ?Q, ?R, ?S, ?T, ?U, ?V, ?W, ?X, ?Y, ?Z
  }

  @namespace_key :sandbox_namespace

  @type aliases :: {:__aliases__, any(), [atom()]}

  @spec namespace(aliases()) :: aliases()
  def namespace({:__aliases__, meta, args}) when is_list(args) do
    {:__aliases__, meta, [get_namespace() | args]}
  end

  @spec get_namespace() :: atom()
  def get_namespace() do
    case Process.get(@namespace_key) do
      nil ->
        pid = :erlang.term_to_binary(self())

        namespace =
          :crypto.hash(:blake2b, pid)
          |> :binary.part(0, 32)
          |> encode()
          |> String.to_atom()

        Process.put(@namespace_key, namespace)
        namespace

      namespace ->
        namespace
    end
  end

  defp encode(binary) when is_binary(binary) do
    head = :binary.copy(<<elem(@alphabet, 0)>>, zeros(binary))
    body = :binary.decode_unsigned(binary) |> encode(<<>>)
    "NS" <> head <> body
  end

  defp encode(0, acc), do: acc

  defp encode(n, acc) do
    ch = <<elem(@alphabet, rem(n, 52))>>
    encode(div(n, 52), ch <> acc)
  end

  defp zeros(binary), do: zeros(binary, 0)

  defp zeros(<<0::8, rest::binary>>, acc) do
    zeros(rest, acc + 1)
  end

  defp zeros(_, acc), do: acc
end
