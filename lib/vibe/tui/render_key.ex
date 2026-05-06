defmodule Vibe.TUI.RenderKey do
  @moduledoc "Helpers for building stable TUI component render cache keys."

  alias Vibe.TUI.RenderContext

  @spec component(atom(), term(), term(), RenderContext.t()) :: tuple()
  def component(type, id, fingerprint, %RenderContext{} = context) do
    {type, id, fingerprint, context.width, context.theme.name}
  end

  @spec component(atom(), term(), term(), [term()], RenderContext.t()) :: tuple()
  def component(type, id, fingerprint, dimensions, %RenderContext{} = context)
      when is_list(dimensions) do
    List.to_tuple([type, id, fingerprint | dimensions] ++ [context.width, context.theme.name])
  end

  @spec fingerprint(term()) :: non_neg_integer()
  def fingerprint(value), do: :erlang.phash2(value)
end
