defmodule Eqlabs.MixProject do
  use Mix.Project

  def project do
    [
      app: :eqlabs,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Eqlabs.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
