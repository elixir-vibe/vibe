defprotocol Vibe.Transport.JSON.Encodable do
  @moduledoc "Protocol for values that cross external transport JSON boundaries."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Transport.JSON.Encodable, for: Any do
  def value(value), do: Vibe.Storage.JSON.value(value)
end
