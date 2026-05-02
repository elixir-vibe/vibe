import Config

config :opentelemetry, processors: []

config :exy, ecto_repos: [Exy.Repo]
config :exy, env: config_env()
config :exy, compile_time_debug: config_env() != :prod

sqlite_busy_timeout_ms = 5_000

config :exy, Exy.Repo,
  journal_mode: :wal,
  busy_timeout: sqlite_busy_timeout_ms,
  pool_size: 1,
  log: false

config :exy, Exy.Web.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [html: Exy.Web.ErrorHTML], layout: false],
  pubsub_server: Exy.PubSub,
  secret_key_base: String.duplicate("0", 64),
  live_view: [signing_salt: "exy-web-signing-salt-2026"]

config :volt,
  entry: "web/app.ts",
  root: "assets",
  outdir: "priv/static/assets",
  target: :es2020,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  tailwind: [
    css: "web/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{ts,css}"}
    ]
  ]

config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/", "assets/"]
