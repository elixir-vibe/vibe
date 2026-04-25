defmodule Exy.TUI.Widgets.Tools.Write do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget
  alias Exy.TUI.Widgets.Tools.FileTool

  @impl true
  def render(tool, width, theme) do
    result = ToolWidget.output(tool)

    ToolWidget.block(tool, width, theme,
      name: :write,
      summary: FileTool.path_summary(tool, result),
      params?: false,
      output_lines:
        Exy.TUI.Widgets.Tools.FileMutation.output_lines(result, max(width - 2, 1), theme)
    )
  end
end
