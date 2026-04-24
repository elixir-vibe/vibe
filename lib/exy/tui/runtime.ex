defmodule Exy.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Exy's interactive TUI.
  """

  alias Exy.TUI.TerminalLoop

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    {columns, rows} = Ghostty.TTY.size()

    opts =
      opts
      |> Keyword.put_new(:width, columns)
      |> Keyword.put_new(:height, rows)
      |> Keyword.put(:output, false)
      |> Keyword.put(:event_target, self())

    with {:ok, loop} <- TerminalLoop.start_link(opts),
         {:ok, tty} <- Ghostty.TTY.start_link(owner: self()) do
      try do
        render(tty, loop)
        receive_events(tty, loop)
      after
        Ghostty.TTY.write(tty, IO.ANSI.reset())
        GenServer.stop(tty)
      end
    end
  end

  defp receive_events(tty, loop) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]}}} ->
        :ok

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape}}} ->
        :ok

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        render(tty, loop)
        receive_events(tty, loop)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        render(tty, loop)
        receive_events(tty, loop)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        render(tty, loop)
        receive_events(tty, loop)

      {TerminalLoop, :event, _event} ->
        render(tty, loop)
        receive_events(tty, loop)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp render(tty, loop) do
    lines = TerminalLoop.render(loop)
    Ghostty.TTY.write(tty, [IO.ANSI.home(), IO.ANSI.clear(), Enum.intersperse(lines, "\n")])
  end
end
