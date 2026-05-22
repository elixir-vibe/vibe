defmodule Vibe.TUI.RenderFrame do
  @moduledoc "Rendered TUI frame with cursor position and renderer cache state."

  alias Vibe.TUI.RenderState

  defstruct lines: [], cursor: {1, 1}, state: RenderState.new(), stats: %{}, body: [], editor: []

  @type cursor :: {pos_integer(), pos_integer()}
  @type t :: %__MODULE__{
          lines: [IO.chardata()],
          cursor: cursor(),
          state: RenderState.t(),
          stats: map(),
          body: [IO.chardata()],
          editor: [IO.chardata()]
        }
end
