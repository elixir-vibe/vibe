defmodule Exy.Paths do
  @moduledoc false

  @spec home() :: String.t()
  def home do
    :exy
    |> Application.get_env(:home_dir, "~/.exy")
    |> Path.expand()
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

  @spec skills_dir() :: String.t()
  def skills_dir, do: Path.join(home(), "skills")
end
