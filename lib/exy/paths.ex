defmodule Exy.Paths do
  @moduledoc "Canonical filesystem paths for Exy runtime data."
  @spec home() :: String.t()
  def home do
    (System.get_env("EXY_HOME") || Application.get_env(:exy, :home_dir, "~/.exy"))
    |> Path.expand()
  end

  @spec database() :: String.t()
  def database do
    System.get_env("EXY_DB_PATH") || Application.get_env(:exy, :database_path) ||
      default_database()
  end

  defp default_database do
    key = {__MODULE__, :default_database}

    case :persistent_term.get(key, nil) do
      nil ->
        database = build_default_database()
        :persistent_term.put(key, database)
        database

      database ->
        database
    end
  end

  defp build_default_database do
    case Application.get_env(:exy, :env) do
      :test -> Path.join(System.tmp_dir!(), "exy-test-#{System.unique_integer([:positive])}.db")
      _env -> Path.join(home(), "exy.db")
    end
  end

  @spec auth_file() :: String.t()
  def auth_file, do: Path.join(home(), "auth.json")

  @spec server_cookie() :: String.t()
  def server_cookie, do: Path.join(home(), "server.cookie")

  @spec server_metadata() :: String.t()
  def server_metadata, do: Path.join(home(), "server.json")

  @spec server_log() :: String.t()
  def server_log, do: Path.join(home(), "server.out")

  @spec sessions_dir() :: String.t()
  def sessions_dir do
    System.get_env("EXY_SESSION_DIR") || Application.get_env(:exy, :session_dir) ||
      Path.join(home(), "sessions")
  end

  @spec telemetry_dir() :: String.t()
  def telemetry_dir do
    System.get_env("EXY_TELEMETRY_DIR") || Application.get_env(:exy, :telemetry_dir) ||
      Path.join(home(), "telemetry")
  end

  @spec telemetry_events() :: String.t()
  def telemetry_events, do: Path.join(telemetry_dir(), "events.jsonl")

  @spec memory_dir() :: String.t()
  def memory_dir do
    System.get_env("EXY_MEMORY_DIR") || Application.get_env(:exy, :memory_dir) ||
      Path.join(home(), "memory")
  end

  @spec agent_profiles() :: String.t()
  def agent_profiles do
    System.get_env("EXY_AGENT_PROFILES") || Application.get_env(:exy, :agent_profiles_file) ||
      Path.join(home(), "agent-profiles.toml")
  end

  @spec subagents_dir() :: String.t()
  def subagents_dir do
    System.get_env("EXY_SUBAGENTS_DIR") || Application.get_env(:exy, :subagents_dir) ||
      Path.join(home(), "subagents")
  end

  @spec subagent_schedules() :: String.t()
  def subagent_schedules, do: Path.join(subagents_dir(), "schedules.jsonl")

  @spec skills_dir() :: String.t()
  def skills_dir, do: Path.join(home(), "skills")
end
