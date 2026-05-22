defmodule Vibe.Event.AssistantStream do
  @moduledoc "Typed semantic assistant streaming event payloads."

  defmodule Started do
    @moduledoc "Payload for an assistant stream starting."
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule Delta do
    @moduledoc "Payload for assistant visible-text streaming."
    @enforce_keys [:text]
    defstruct [:text]

    @type t :: %__MODULE__{text: String.t()}
  end

  defmodule ThinkingDelta do
    @moduledoc "Payload for assistant hidden-thinking streaming."
    @enforce_keys [:text]
    defstruct [:text]

    @type t :: %__MODULE__{text: String.t()}
  end

  defmodule Finished do
    @moduledoc "Payload for an assistant stream finishing."
    defstruct [:text]

    @type t :: %__MODULE__{text: String.t() | nil}
  end

  defmodule Aborted do
    @moduledoc "Payload for an assistant response aborting."
    defstruct reason: "Cancelled.", notify?: true

    @type t :: %__MODULE__{reason: String.t(), notify?: boolean()}
  end

  @spec started() :: Started.t()
  def started, do: %Started{}

  @spec delta(String.t()) :: Delta.t()
  def delta(text) when is_binary(text), do: %Delta{text: text}

  @spec thinking_delta(String.t()) :: ThinkingDelta.t()
  def thinking_delta(text) when is_binary(text), do: %ThinkingDelta{text: text}

  @spec finished(String.t() | nil) :: Finished.t()
  def finished(text \\ nil), do: %Finished{text: text}

  @spec aborted(map() | keyword()) :: Aborted.t()
  def aborted(attrs \\ %{}), do: attrs |> Map.new() |> then(&struct(Aborted, &1))
end
