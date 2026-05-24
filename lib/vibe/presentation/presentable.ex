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
  def present(%{role: :eval} = eval), do: Vibe.Presentation.EvalExecution.present(eval)
  def present(%{name: _name} = tool), do: Vibe.Presentation.Tool.from_tool(tool)
  def present(value), do: value
end

defimpl Vibe.Presentation.Presentable, for: Vibe.UI.Block.EvalExecution do
  def present(eval), do: Vibe.Presentation.EvalExecution.present(eval)
end

defimpl Vibe.Presentation.Presentable, for: Vibe.Tool.Event do
  def present(event), do: Vibe.Presentation.Tool.from_tool(event)
end
