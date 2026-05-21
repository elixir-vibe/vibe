defmodule Vibe.Event.RuntimeAlert do
  @moduledoc "Typed semantic runtime alert event payloads."

  alias Vibe.SystemAlarms.Alert

  defmodule Set do
    @moduledoc "Payload for a runtime alert being set."
    @enforce_keys [:alert]
    defstruct [:alert]

    @type t :: %__MODULE__{alert: Alert.t()}
  end

  defmodule Cleared do
    @moduledoc "Payload for a runtime alert being cleared."
    @enforce_keys [:alert]
    defstruct [:alert]

    @type t :: %__MODULE__{alert: Alert.t()}
  end

  @spec set(Alert.t()) :: Set.t()
  def set(%Alert{} = alert), do: %Set{alert: alert}

  @spec cleared(Alert.t()) :: Cleared.t()
  def cleared(%Alert{} = alert), do: %Cleared{alert: alert}
end
