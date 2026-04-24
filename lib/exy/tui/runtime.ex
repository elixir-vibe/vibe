defmodule Exy.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Exy's interactive TUI.
  """

  alias Exy.TUI.{TerminalLoop, TerminalMode}

  @escape_timeout 30
  @resize_interval 250

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    {columns, rows} = terminal_size()
    opts = opts |> Keyword.put_new(:width, columns) |> Keyword.put_new(:height, rows)

    with {:ok, loop} <- TerminalLoop.start_link(opts) do
      with_terminal(fn -> input_loop(loop) end)
    end
  end

  defp with_terminal(fun) do
    original = TerminalMode.snapshot()

    case TerminalMode.raw() do
      :ok ->
        try do
          IO.write([IO.ANSI.home(), IO.ANSI.clear()])
          fun.()
        after
          IO.write(IO.ANSI.reset())
          TerminalMode.restore(original)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp input_loop(loop) do
    TerminalLoop.resize(loop, elem(terminal_size(), 0), elem(terminal_size(), 1))
    parent = self()
    reader = spawn(fn -> read_stdin(parent) end)
    schedule_resize()

    try do
      receive_input(loop, reader)
    after
      Process.exit(reader, :kill)
    end
  end

  defp receive_input(loop, reader) do
    receive do
      {:stdin, :eof} ->
        :ok

      {:stdin, <<3>>} ->
        :ok

      {:stdin, "\e"} ->
        case collect_escape() do
          "\e" -> :ok
          sequence -> TerminalLoop.input(loop, sequence)
        end

        receive_input(loop, reader)

      {:stdin, data} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        receive_input(loop, reader)

      :resize_tick ->
        TerminalLoop.resize(loop, elem(terminal_size(), 0), elem(terminal_size(), 1))
        schedule_resize()
        receive_input(loop, reader)
    end
  end

  defp schedule_resize, do: Process.send_after(self(), :resize_tick, @resize_interval)

  defp read_stdin(parent) do
    case IO.getn(:stdio, "", 1) do
      :eof ->
        send(parent, {:stdin, :eof})

      data when is_binary(data) ->
        send(parent, {:stdin, data})
        read_stdin(parent)
    end
  end

  defp collect_escape do
    receive do
      {:stdin, second} when is_binary(second) -> "\e" <> second <> collect_escape_tail(second)
    after
      @escape_timeout -> "\e"
    end
  end

  defp collect_escape_tail("[") do
    receive do
      {:stdin, third} when is_binary(third) -> third <> maybe_collect_escape_suffix(third)
    after
      @escape_timeout -> ""
    end
  end

  defp collect_escape_tail(_second), do: ""

  defp maybe_collect_escape_suffix(third)
       when third in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] do
    receive do
      {:stdin, suffix} when is_binary(suffix) -> suffix
    after
      @escape_timeout -> ""
    end
  end

  defp maybe_collect_escape_suffix(_third), do: ""

  defp terminal_size do
    columns =
      case :io.columns() do
        {:ok, value} -> value
        _ -> 100
      end

    rows =
      case :io.rows() do
        {:ok, value} -> value
        _ -> 30
      end

    {columns, rows}
  end
end
