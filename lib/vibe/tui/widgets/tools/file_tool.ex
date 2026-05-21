defmodule Vibe.TUI.Widgets.Tools.FileTool do
  @moduledoc "TUI tool widget: shared file path summary."
  alias Vibe.Tool.Presentation.Util
  alias Vibe.TUI.ToolWidget

  @spec path_summary(map(), term()) :: String.t() | nil
  def path_summary(tool, result),
    do:
      Util.path_from_args(tool) || Util.path_from_result(result) ||
        ToolWidget.compact_summary(tool)
end
