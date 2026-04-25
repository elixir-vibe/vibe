defmodule Exy.TUI.Views.Chat do
  @moduledoc """
  Default declarative chat TUI view.
  """

  use Exy.TUI

  defui do
    vertical do
      body =
        for block <- assign(:body) do
          case block do
            %Exy.UI.Block.ToolCall{} -> tool(block)
            _ -> message(block)
          end
        end

      body = Enum.intersperse(body, spacer())
      plugin_widgets = Enum.map(assign(:plugin_widgets), &plugin_widget/1)
      notices = if assign(:notifications), do: [notifications(assign(:notifications))], else: []
      overlays = Enum.map(assign(:overlays), &overlay/1)

      List.flatten([body, plugin_widgets, notices, footer(assign(:footer)), overlays])
    end
  end
end
