defmodule Vibe.Event.Tool do
  @moduledoc "Typed semantic tool lifecycle event payloads."

  defmodule Started do
    @moduledoc "Payload for a tool starting."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: term()}
  end

  defmodule Updated do
    @moduledoc "Payload for a tool update."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: term()}
  end

  defmodule Finished do
    @moduledoc "Payload for a tool finishing."
    @enforce_keys [:event]
    defstruct [:event]

    @type t :: %__MODULE__{event: term()}
  end

  @spec started(term()) :: Started.t()
  def started(event), do: %Started{event: event}

  @spec updated(term()) :: Updated.t()
  def updated(event), do: %Updated{event: event}

  @spec finished(term()) :: Finished.t()
  def finished(event), do: %Finished{event: event}
end
