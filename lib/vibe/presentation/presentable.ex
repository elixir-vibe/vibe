defprotocol Vibe.Presentation.Presentable do
  @moduledoc "Converts domain values into renderer-neutral presentation values."

  @fallback_to_any true

  @spec present(t()) :: term()
  def present(value)
end

defimpl Vibe.Presentation.Presentable, for: Any do
  def present(value), do: value
end

defimpl Vibe.Presentation.Presentable, for: Map do
  def present(%{name: _name} = tool), do: Vibe.Tool.Presentation.from_tool(tool)
  def present(value), do: value
end

defimpl Vibe.Presentation.Presentable, for: Vibe.Tool.Event do
  def present(event), do: Vibe.Tool.Presentation.from_tool(event)
end
