defmodule Vibe.Event.Tool do
  @moduledoc "Typed semantic tool lifecycle event payloads."

  alias Vibe.Tool.Event

  defmodule Started do
    @moduledoc "Payload for a tool starting."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: Event.t()}
  end

  defmodule Updated do
    @moduledoc "Payload for a tool update."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: Event.t()}
  end

  defmodule Finished do
    @moduledoc "Payload for a tool finishing."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: Event.t()}
  end

  @spec started(Event.t()) :: Started.t()
  def started(%Event{} = event), do: %Started{event: event}

  @spec updated(Event.t()) :: Updated.t()
  def updated(%Event{} = event), do: %Updated{event: event}

  @spec finished(Event.t()) :: Finished.t()
  def finished(%Event{} = event), do: %Finished{event: event}
end
