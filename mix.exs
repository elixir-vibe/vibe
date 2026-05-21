defmodule Vibe.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/elixir-vibe/vibe"

  def project do
    [
      app: :vibe,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers() ++ [:phoenix_iconify],
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "BEAM-native coding agent substrate for Elixir/OTP projects",
      source_url: @source_url,
      package: package(),
      aliases: aliases(),
      escript: escript(),
      dialyzer: [
        plt_file: {:no_warn, "_build/dev/dialyxir_plt.plt"},
        plt_add_apps: [:mix, :credo, :ex_dna, :ex_slop, :reach]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tools, :mix, :ssh, :public_key, :crypto],
      mod: {Vibe.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(assets config lib priv mix.exs mix.lock README.md LICENSE)
    ]
  end

  defp escript do
    [
      main_module: Vibe.CLI.Escript,
      name: "vibe",
      app: nil,
      include_priv_for: [
        :vibe,
        :tzdata,
        :llm_db,
        :mdex,
        :lumis,
        :oxc,
        :ghostty,
        :quickbeam,
        :pythonx,
        :exqlite,
        :volt,
        :vize,
        :oxide_ex
      ],
      strip_beams: [keep: ["Docs"]]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:abnf_parsec, "~> 2.1"},
      {:boxart, "~> 0.3.3"},
      {:ex_ast, "~> 0.12"},
      {:floki, "~> 0.38"},
      {:glob_ex, "~> 0.1.11"},
      {:jason, "~> 1.4"},
      {:json_spec, "~> 1.1"},
      {:mdex, "~> 0.12"},
      {:yaml_elixir, "~> 2.12"},
      {:toml, "~> 0.7"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.23"},
      {:ex_gram, "~> 0.66"},
      {:req, "~> 0.5.18"},
      {:req_llm, "~> 1.11"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_streamdown, "~> 1.0.0-beta"},
      {:phoenix_iconify, "~> 0.3.0"},
      {:plug_cowboy, "~> 2.7"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:volt, "~> 0.12"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_telemetry, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.5", runtime: false},
      {:dune, "~> 0.3", optional: true},
      {:pythonx, "~> 0.4.10", optional: true},
      {:quickbeam, "~> 0.10.14", optional: true},
      {:jido, "~> 2.2"},
      {:jido_ai, "~> 2.1"},
      {:ghostty, "~> 0.4.8"}
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
        "ex_dna",
        "reach.check --smells --strict"
      ]
    ]
  end
end
