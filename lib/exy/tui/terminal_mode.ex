defmodule Exy.TUI.TerminalMode do
  @moduledoc """
  Terminal mode adapter for the interactive TUI.

  Elixir/OTP exposes ANSI output helpers through `IO.ANSI`, but it does not
  provide an equivalent raw-mode API for stdin. Keep the unavoidable `stty`
  calls isolated here so runtime code stays semantic and the shell dependency is
  easy to replace if a maintained terminal-mode library becomes available.
  """

  @type snapshot :: String.t() | nil

  @spec snapshot() :: snapshot()
  def snapshot, do: stty(["-g"])

  @spec raw() :: :ok | {:error, String.t()}
  def raw do
    case System.cmd("stty", ["raw", "-echo"], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _status} -> {:error, String.trim(output)}
    end
  end

  @spec restore(snapshot()) :: :ok
  def restore(nil), do: sane()
  def restore(mode) when is_binary(mode), do: mode |> List.wrap() |> stty_ok()

  @spec sane() :: :ok
  def sane, do: stty_ok(["sane"])

  defp stty(args) do
    case System.cmd("stty", args, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  defp stty_ok(args) do
    _ignored = stty(args)
    :ok
  end
end
