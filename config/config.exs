import Config

config :opentelemetry, processors: []

config :ex_gram, adapter: ExGram.Adapter.Req

config :vibe, ecto_repos: [Vibe.Repo]
config :vibe, env: config_env()
config :vibe, compile_time_debug: config_env() != :prod
config :vibe, web: config_env() != :test

if config_env() == :test do
  config :vibe, tui_hyperlinks: false
end

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
  secret_key_base: String.duplicate("vibe-test-secret-key-base-", 4),
  live_view: [signing_salt: "vibe-web-signing-salt-2026"]

config :volt,
  entry: "assets/web/app.ts",
  root: "assets",
  outdir: "priv/static/assets",
  target: :es2020,
  resolve_dirs: ["deps"],
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

config :phoenix_iconify,
  fallback: "lucide:circle-help",
  extra_icons: [
    "lucide:activity",
    "lucide:bell",
    "lucide:book-open",
    "lucide:brain",
    "lucide:chevron-left",
    "lucide:chevron-right",
    "lucide:circle-check",
    "lucide:circle-help",
    "lucide:circle-stop",
    "lucide:circle-x",
    "lucide:coins",
    "lucide:cpu",
    "lucide:database",
    "lucide:eraser",
    "lucide:folder",
    "lucide:gauge",
    "lucide:hash",
    "lucide:info",
    "lucide:keyboard",
    "lucide:loader-circle",
    "lucide:message-circle",
    "lucide:message-square",
    "lucide:messages-square",
    "lucide:moon",
    "lucide:plug",
    "lucide:plus",
    "lucide:radio",
    "lucide:radio-tower",
    "lucide:scan-line",
    "lucide:search",
    "lucide:send",
    "lucide:settings",
    "lucide:sparkles",
    "lucide:sun",
    "lucide:trash-2",
    "lucide:triangle-alert",
    "lucide:workflow",
    "lucide:wrench"
  ]
