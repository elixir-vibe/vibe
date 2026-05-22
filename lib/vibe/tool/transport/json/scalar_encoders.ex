defimpl Vibe.Tool.Transport.JSON.Encodable, for: DateTime do
  def value(value), do: DateTime.to_iso8601(value)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Date do
  def value(value), do: Date.to_iso8601(value)
end
