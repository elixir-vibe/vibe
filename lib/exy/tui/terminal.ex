defmodule Exy.TUI.Terminal do
  @moduledoc """
  Minimal Ghostty-backed terminal pane primitive.

  This is not yet a full TUI. It gives Exy a BEAM-native terminal surface that
  can run interactive commands and snapshot ANSI output as text or HTML.
  """

  @spec start(keyword()) :: {:ok, map()} | {:error, term()}
  def start(opts \\ []) do
    with {:ghostty, true} <- {:ghostty, Code.ensure_loaded?(Ghostty.Terminal)},
         {:ok, term} <-
           Ghostty.Terminal.start_link(
             cols: Keyword.get(opts, :cols, 100),
             rows: Keyword.get(opts, :rows, 30)
           ),
         {:ok, pty} <-
           Ghostty.PTY.start_link(
             cmd: Keyword.get(opts, :cmd, shell()),
             cols: Keyword.get(opts, :cols, 100),
             rows: Keyword.get(opts, :rows, 30)
           ) do
      {:ok, %{term: term, pty: pty}}
    else
      {:ghostty, false} -> {:error, :ghostty_not_available}
      other -> other
    end
  end

  @spec write(map(), binary()) :: :ok | {:error, term()}
  def write(%{pty: pty}, data) when is_binary(data), do: Ghostty.PTY.write(pty, data)

  @spec pump_once(map(), timeout()) :: {:ok, binary()} | {:exit, term()} | :timeout
  def pump_once(%{term: term}, timeout \\ 100) do
    receive do
      {:data, data} ->
        Ghostty.Terminal.write(term, data)
        {:ok, data}

      {:exit, status} ->
        {:exit, status}
    after
      timeout -> :timeout
    end
  end

  @spec snapshot(map(), :text | :html) :: {:ok, binary()} | {:error, term()}
  def snapshot(%{term: term}, :text), do: Ghostty.Terminal.snapshot(term)
  def snapshot(%{term: term}, :html), do: Ghostty.Terminal.snapshot(term, :html)

  defp shell, do: System.get_env("SHELL") || "/bin/sh"
end
