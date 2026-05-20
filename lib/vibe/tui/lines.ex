defmodule Vibe.TUI.Lines do
  @moduledoc "Line list manipulation helpers for TUI rendering."
  alias Vibe.Support.Lists

  @type line :: IO.chardata()

  @doc "Intentional facade for the public Vibe API boundary."
  @spec append([line()], line()) :: [line()]
  defdelegate append(lines, line), to: Lists

  @spec append_if([line()], boolean(), line()) :: [line()]
  def append_if(lines, true, line), do: append(lines, line)
  def append_if(lines, false, _line), do: lines

  @doc "Intentional facade for the public Vibe API boundary."
  @spec join([line()], [line()]) :: [line()]
  defdelegate join(left, right), to: Lists
end
