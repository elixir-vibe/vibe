defmodule Exy.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/exy"

  def project do
    [
      app: :exy,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "BEAM-native coding agent substrate for Elixir/OTP projects",
      source_url: @source_url,
      package: package(),
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "_build/dev/dialyxir_plt.plt"},
        plt_add_apps: [:mix, :credo, :ex_dna, :ex_slop]
      ]
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
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv test mix.exs mix.lock README.md AGENTS.md .formatter.exs .gitignore)
    ]
  end

  defp deps do
    [
      {:ex_ast, "~> 0.5.0"},
      {:jason, "~> 1.4"},
      {:json_spec, "~> 1.1"},
      {:mdex, "~> 0.12"},
      {:yaml_elixir, "~> 2.12"},
      {:req, "~> 0.5"},
      {:req_llm, "~> 1.10"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 1.7", only: [:dev, :test], runtime: false},
      {:pythonx, "~> 0.4.9", optional: true},
      {:quickbeam, "~> 0.10.4", optional: true},
      {:jido, "~> 2.2"},
      {:jido_ai, "~> 2.1"},
      {:ghostty, "~> 0.4"}
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna"
      ]
    ]
  end
end
