import Config

config :logger, level: :info

config :try_elixir,
  secret_key_base: urandom(64),
  encryption_salt: urandom(32),
  signing_salt: urandom(32)

@block_size 512

defp urandom(count) when count > 0 do
  urandom(count, <<>>)
end

defp urandom(0, acc), do: acc

defp urandom(remainder, acc) when remainder > @block_size do
  count = div(remainder, @block_size)

  {bytes, 0} =
    System.cmd("dd", ["bs=#{@block_size}", "count=#{count}", "if=/dev/urandom", "status=none"])

  urandom(remainder - byte_size(bytes), acc <> bytes)
end

defp urandom(remainder, acc) when remainder > 0 do
  {bytes, 0} = System.cmd("dd", ["bs=#{remainder}", "count=1", "if=/dev/urandom", "status=none"])
  urandom(remainder - byte_size(bytes), acc <> bytes)
end
