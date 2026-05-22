defprotocol Vibe.Tool.Transport.JSON.Encodable do
  @moduledoc "Protocol for values that cross the model-facing tool JSON boundary."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Any do
  def value(value), do: Vibe.Tool.Transport.JSON.Value.value(value)
end
