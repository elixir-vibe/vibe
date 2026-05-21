defprotocol Vibe.Storage.Restorable do
  @moduledoc "Restores current storage representation structs into typed Vibe values."

  @spec restore(t()) :: term()
  def restore(value)
end
