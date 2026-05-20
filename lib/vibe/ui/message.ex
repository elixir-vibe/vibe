defmodule Vibe.UI.Message do
  @moduledoc "Semantic chat message in UI state."

  @behaviour Access

  defstruct [
    :at,
    :content,
    :delta,
    :error,
    :id,
    :image_count,
    :name,
    :part,
    :result,
    :text,
    :thinking,
    :tool,
    role: :assistant,
    streaming?: false
  ]

  @impl Access
  def fetch(message, key), do: Map.fetch(Map.from_struct(message), key)

  @impl Access
  def get_and_update(message, key, fun) do
    current = Map.get(message, key)

    case fun.(current) do
      {get, update} -> {get, struct(__MODULE__, Map.put(Map.from_struct(message), key, update))}
      :pop -> {current, struct(__MODULE__, Map.delete(Map.from_struct(message), key))}
    end
  end

  @impl Access
  def pop(message, key) do
    {Map.get(message, key), struct(__MODULE__, Map.delete(Map.from_struct(message), key))}
  end
end
