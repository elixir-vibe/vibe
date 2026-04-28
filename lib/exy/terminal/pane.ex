defmodule Exy.Terminal.Pane do
  @moduledoc """
  Supervised Ghostty terminal + optional PTY pane.

  This powers embedded terminal surfaces for TUI and future LiveView widgets. It
  is intentionally separate from the semantic Exy chat UI.
  """

  use GenServer

  @default_shutdown_ms 5_000
  @default_max_scrollback_lines 10_000

  @type snapshot_format :: :plain | :html | :vt

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :id, {__MODULE__, make_ref()}),
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: @default_shutdown_ms
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec write(GenServer.server(), iodata()) :: :ok
  def write(pane, data), do: GenServer.call(pane, {:write, IO.iodata_to_binary(data)})

  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(pane, cols, rows), do: GenServer.call(pane, {:resize, cols, rows})

  @spec snapshot(GenServer.server(), snapshot_format()) :: {:ok, binary()} | {:error, term()}
  def snapshot(pane, format \\ :plain), do: GenServer.call(pane, {:snapshot, format})

  @spec render_state(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def render_state(pane), do: GenServer.call(pane, :render_state)

  @spec close(GenServer.server()) :: :ok
  def close(pane), do: GenServer.stop(pane)

  @impl true
  def init(opts) do
    with {:ghostty, true} <- {:ghostty, Code.ensure_loaded?(Ghostty.Terminal)},
         {:ok, term} <- start_terminal(opts),
         {:ok, pty} <- maybe_start_pty(opts) do
      {:ok,
       %{
         term: term,
         pty: pty,
         cols: Keyword.get(opts, :cols, 100),
         rows: Keyword.get(opts, :rows, 30)
       }}
    else
      {:ghostty, false} -> {:stop, :ghostty_not_available}
      {:error, reason} -> {:stop, reason}
      other -> {:stop, other}
    end
  end

  @impl true
  def handle_call({:write, data}, _from, %{pty: nil, term: term} = state) do
    :ok = Ghostty.Terminal.write(term, data)
    {:reply, :ok, state}
  end

  def handle_call({:write, data}, _from, %{pty: pty} = state) do
    :ok = Ghostty.PTY.write(pty, data)
    {:reply, :ok, state}
  end

  def handle_call({:resize, cols, rows}, _from, state) do
    :ok = Ghostty.Terminal.resize(state.term, cols, rows)
    if state.pty, do: Ghostty.PTY.resize(state.pty, cols, rows)
    {:reply, :ok, %{state | cols: cols, rows: rows}}
  end

  def handle_call({:snapshot, format}, _from, state) do
    {:reply, Ghostty.Terminal.snapshot(state.term, format), state}
  end

  def handle_call(:render_state, _from, state) do
    {:reply, {:ok, Ghostty.Terminal.render_state(state.term)}, state}
  end

  @impl true
  def handle_info({:data, data}, state) do
    Ghostty.Terminal.write(state.term, data)
    {:noreply, state}
  end

  def handle_info({:pty_write, data}, %{pty: pty} = state) when is_pid(pty) do
    Ghostty.PTY.write(pty, data)
    {:noreply, state}
  end

  def handle_info({:exit, status}, state), do: {:stop, {:pty_exit, status}, state}
  def handle_info(_message, state), do: {:noreply, state}

  defp start_terminal(opts) do
    Ghostty.Terminal.start_link(
      cols: Keyword.get(opts, :cols, 100),
      rows: Keyword.get(opts, :rows, 30),
      max_scrollback: Keyword.get(opts, :max_scrollback, @default_max_scrollback_lines)
    )
  end

  defp maybe_start_pty(opts) do
    if Keyword.get(opts, :pty, true) do
      Ghostty.PTY.start_link(
        cmd: Keyword.get(opts, :cmd, shell()),
        args: Keyword.get(opts, :args, []),
        cols: Keyword.get(opts, :cols, 100),
        rows: Keyword.get(opts, :rows, 30)
      )
    else
      {:ok, nil}
    end
  end

  defp shell, do: System.get_env("SHELL") || "/bin/sh"
end
