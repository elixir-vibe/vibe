import Config

config :opentelemetry, processors: []

config :exy, ecto_repos: [Exy.Repo]
config :exy, env: config_env()

config :exy, Exy.Repo,
  journal_mode: :wal,
  busy_timeout: 5_000,
  pool_size: 1,
  log: false
