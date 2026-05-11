import Config

config :opentelemetry, processors: []

config :ex_gram, adapter: ExGram.Adapter.Req

config :vibe, ecto_repos: [Vibe.Repo]
config :vibe, env: config_env()
config :vibe, compile_time_debug: config_env() != :prod

sqlite_busy_timeout_ms = 5_000

config :vibe, Vibe.Repo,
  journal_mode: :wal,
  busy_timeout: sqlite_busy_timeout_ms,
  pool_size: 1,
  log: false

config :vibe, Vibe.Web.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [html: Vibe.Web.ErrorHTML], layout: false],
  pubsub_server: Vibe.PubSub,
  secret_key_base: String.duplicate("0", 64),
  live_view: [signing_salt: "vibe-web-signing-salt-2026"]

config :volt,
  entry: "assets/web/app.ts",
  root: "assets",
  outdir: "priv/static/assets",
  target: :es2020,
  external: ~w(phoenix phoenix_html phoenix_live_view),
  tailwind: [
    css: "assets/web/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{ts,css}"}
    ]
  ]

config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/", "assets/"]
