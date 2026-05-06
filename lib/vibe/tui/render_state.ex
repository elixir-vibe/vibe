defmodule Vibe.TUI.RenderState do
  @moduledoc "Renderer-owned cache for TUI component line output."

  defstruct components: %{}, hits: 0, misses: 0

  @type key :: term()
  @type lines :: [IO.chardata()]
  @type t :: %__MODULE__{
          components: %{optional(key()) => lines()},
          hits: non_neg_integer(),
          misses: non_neg_integer()
        }

  @spec new(keyword()) :: t()
  def new(_opts \\ []), do: %__MODULE__{}

  @spec fetch(t(), key()) :: {:ok, lines(), t()} | :miss
  def fetch(%__MODULE__{} = state, key) do
    case Map.fetch(state.components, key) do
      {:ok, lines} -> {:ok, lines, %{state | hits: state.hits + 1}}
      :error -> :miss
    end
  end

  @spec put(t(), key(), lines()) :: t()
  def put(%__MODULE__{} = state, key, lines) when is_list(lines) do
    %{state | components: Map.put(state.components, key, lines), misses: state.misses + 1}
  end

  @spec prune(t(), [key()]) :: t()
  def prune(%__MODULE__{} = state, live_keys) when is_list(live_keys) do
    live = MapSet.new(live_keys)
    %{state | components: Map.take(state.components, MapSet.to_list(live))}
  end

  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = state) do
    %{entries: map_size(state.components), hits: state.hits, misses: state.misses}
  end
end
