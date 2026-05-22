defmodule Vibe.Presentation.Tool.Display do
  @moduledoc "Renderer-neutral presentation value for tool lifecycle events and results."

  defstruct name: nil,
            status: nil,
            summary: nil,
            summary_style: nil,
            meta: [],
            body: [],
            expanded?: false,
            truncate?: true

  @type block ::
          {:text, String.t(), keyword()}
          | {:inspect, String.t(), keyword()}
          | {:markdown, String.t(), keyword()}
          | {:source, String.t(), keyword()}
          | {:error, String.t(), keyword()}
          | {:diff, String.t(), keyword()}
          | {:lines, [IO.chardata()], keyword()}
          | {:image, map(), keyword()}

  @type t :: %__MODULE__{
          name: atom() | String.t() | nil,
          status: atom() | String.t() | nil,
          summary: IO.chardata() | nil,
          summary_style: atom() | nil,
          meta: [IO.chardata()],
          body: [block()],
          expanded?: boolean(),
          truncate?: boolean()
        }
end
