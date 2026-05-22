defmodule Vibe.Event.Session do
  @moduledoc "Typed semantic session event payloads."

  defmodule Selected do
    @moduledoc "Payload for selecting a different session."
    @enforce_keys [:session_id]
    defstruct [:session_id]

    @type t :: %__MODULE__{session_id: String.t()}
  end

  defmodule NewRequested do
    @moduledoc "Payload for requesting a new session."
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule Backgrounded do
    @moduledoc "Payload for backgrounding the current session."
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule ActiveCountUpdated do
    @moduledoc "Payload for the active-session count changing."
    @enforce_keys [:count]
    defstruct [:count]

    @type t :: %__MODULE__{count: non_neg_integer()}
  end

  @spec selected(String.t()) :: Selected.t()
  def selected(session_id) when is_binary(session_id), do: %Selected{session_id: session_id}

  @spec new_requested() :: NewRequested.t()
  def new_requested, do: %NewRequested{}

  @spec backgrounded() :: Backgrounded.t()
  def backgrounded, do: %Backgrounded{}

  @spec active_count_updated(non_neg_integer()) :: ActiveCountUpdated.t()
  def active_count_updated(count) when is_integer(count) and count >= 0,
    do: %ActiveCountUpdated{count: count}
end
