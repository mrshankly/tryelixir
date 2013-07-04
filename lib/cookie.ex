defmodule Tryelixir.Cookie do
	@moduledoc """
	Signed cookies.
	"""
	@secret "change_me"

	def encode(cookie) do
		ck = :base64.encode(cookie)
		signature = :base64.encode(:crypto.hash(:sha, [ck, @secret]))
		<<signature :: binary, ck :: binary>>
	end

	def decode(cookie) do
		<<signature :: [size(28), binary], ck :: binary>> = cookie
		if signature == :base64.encode(:crypto.hash(:sha, [ck, @secret])) do
			binary_to_list(:base64.decode(ck))
		else
			:error
		end
	end
end
