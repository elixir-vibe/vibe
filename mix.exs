defmodule Exy.MixProject do
  use Mix.Project

  def project do
    [
      app: :exy,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tools],
      mod: {Exy.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_ast, "~> 0.5.0"},
      {:jason, "~> 1.4"},
      {:json_spec, "~> 1.1"},
      {:req, "~> 0.5"},
      {:req_llm, "~> 1.10"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.3", only: [:dev, :test], runtime: false},
      {:reach, "~> 1.7", only: [:dev, :test], runtime: false},
      {:pythonx, "~> 0.4.9", optional: true},
      {:quickbeam, "~> 0.10.4", optional: true},
      {:jido, "~> 2.2"},
      {:jido_ai, "~> 2.1"},
      {:ghostty, "~> 0.3.2", optional: true}
    ]
  end
end
