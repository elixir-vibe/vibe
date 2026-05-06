defmodule Vibe.TUI.Duration do
  @moduledoc "Human-readable duration formatting for tool timing."
  @spec milliseconds(term()) :: String.t() | nil
  def milliseconds(ms) when is_integer(ms) and ms > 0 and rem(ms, 1000) == 0,
    do: "#{div(ms, 1000)}s"

  def milliseconds(ms) when is_integer(ms) and ms > 0,
    do: "#{Float.round(ms / 1000, 1)}s"

  def milliseconds(_ms), do: nil
end
