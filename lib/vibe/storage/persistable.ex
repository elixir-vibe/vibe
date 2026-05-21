defprotocol Vibe.Storage.Persistable do
  @moduledoc "Converts typed Vibe values into current storage representation structs."

  @spec persist(t()) :: struct()
  def persist(value)
end
