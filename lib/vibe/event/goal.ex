defmodule Vibe.Event.Goal do
  @moduledoc "Typed semantic goal event payloads."

  alias Vibe.Goals.Goal

  defmodule Set do
    @moduledoc "Payload for setting a session goal."
    @enforce_keys [:goal]
    defstruct [:goal]

    @type t :: %__MODULE__{goal: Goal.t()}
  end

  defmodule Updated do
    @moduledoc "Payload for updating a session goal."
    @enforce_keys [:goal]
    defstruct [:goal]

    @type t :: %__MODULE__{goal: Goal.t()}
  end

  defmodule Cleared do
    @moduledoc "Payload for clearing a session goal."
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule ContinuationStarted do
    @moduledoc "Payload for starting autonomous goal continuation."
    defstruct []

    @type t :: %__MODULE__{}
  end

  @spec set(Goal.t()) :: Set.t()
  def set(%Goal{} = goal), do: %Set{goal: goal}

  @spec updated(Goal.t()) :: Updated.t()
  def updated(%Goal{} = goal), do: %Updated{goal: goal}

  @spec cleared() :: Cleared.t()
  def cleared, do: %Cleared{}

  @spec continuation_started() :: ContinuationStarted.t()
  def continuation_started, do: %ContinuationStarted{}
end
