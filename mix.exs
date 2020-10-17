defmodule TryElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :try_elixir,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [mod: {TryElixir, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.4"},
      {:ex_doc, "~> 0.22", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.4.1", only: [:dev, :test], runtime: false}
    ]
  end
end
