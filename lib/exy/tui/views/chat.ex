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

      overlays = Enum.map(assign(:overlays), &overlay/1)

      List.flatten([body, footer(assign(:footer)), overlays])
    end
  end
end
