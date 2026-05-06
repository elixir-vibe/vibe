defmodule Vibe.TUI.Widgets.Tools.Write do
  @moduledoc "TUI tool widget: file creation result."
  @behaviour Vibe.TUI.ToolWidget

  alias Vibe.TUI.ToolWidget
  alias Vibe.TUI.Widgets.Tools.FileTool

  @impl true
  def render(tool, width, theme) do
    result = ToolWidget.output(tool)

    ToolWidget.block(tool, width, theme,
      name: :write,
      summary: FileTool.path_summary(tool, result),
      params?: false,
      output_lines:
        Vibe.TUI.Widgets.Tools.FileMutation.output_lines(result, max(width - 2, 1), theme)
    )
  end
end
