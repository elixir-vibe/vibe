defmodule Vibe.Presentation.Tool.Generic do
  @moduledoc "Fallback semantic display document for tools without specialized renderers."

  alias Vibe.Presentation.Tool.Display
  alias Vibe.Presentation.Tool.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    %Display{
      name: Map.get(tool, :name),
      status: Map.get(tool, :status),
      summary: Util.generic_summary(tool),
      body: [
        {:inspect, inspect(Map.get(tool, :output) || Map.get(tool, :result), pretty: true),
         truncation: :tail}
      ],
      expanded?: Util.expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end
end
