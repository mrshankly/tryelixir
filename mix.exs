defmodule Tryelixir.Mixfile do
  use Mix.Project

  def project do
    [ app: :tryelixir,
      version: "0.0.1",
      dynamos: [Tryelixir.Dynamo],
      compilers: [:elixir, :dynamo, :app],
      env: [prod: [compile_path: "ebin"]],
      compile_path: "tmp/#{Mix.env}/tryelixir/ebin",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [ applications: [:cowboy, :dynamo],
      mod: { Tryelixir, [] } ]
  end

  defp deps do
    [ { :cowboy, github: "extend/cowboy" },
      { :dynamo, github: "elixir-lang/dynamo" } ]
  end
end
