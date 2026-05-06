defmodule Vibe.TUI.RenderContext do
  @moduledoc "Context passed to TUI renderable protocol implementations."

  alias Vibe.TUI.{RenderState, Theme}

  defstruct [:width, :theme, :state, opts: []]

  @type t :: %__MODULE__{
          width: pos_integer(),
          theme: Theme.t(),
          state: RenderState.t(),
          opts: keyword()
        }

  @spec new(pos_integer(), Theme.t(), RenderState.t(), keyword()) :: t()
  def new(width, theme, %RenderState{} = state, opts \\ [])
      when is_integer(width) and width > 0 do
    %__MODULE__{width: width, theme: theme, state: state, opts: opts}
  end
end
