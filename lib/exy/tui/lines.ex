defmodule Exy.TUI.Lines do
  @moduledoc false

  alias Exy.Support.Lists

  @type line :: IO.chardata()

  @spec append([line()], line()) :: [line()]
  def append(lines, line), do: Lists.append(lines, line)

  @spec append_if([line()], boolean(), line()) :: [line()]
  def append_if(lines, true, line), do: append(lines, line)
  def append_if(lines, false, _line), do: lines

  @spec join([line()], [line()]) :: [line()]
  def join(left, right), do: Lists.join(left, right)
end
