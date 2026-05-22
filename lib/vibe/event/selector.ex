defmodule Vibe.Event.Selector do
  @moduledoc "Typed semantic selector and overlay event payloads."

  defmodule Opened do
    @moduledoc "Payload for opening a selector or confirmation overlay."
    @enforce_keys [:selector]
    defstruct [:selector]

    @type t :: %__MODULE__{selector: term()}
  end

  defmodule Moved do
    @moduledoc "Payload for moving selector focus."
    @enforce_keys [:direction]
    defstruct [:direction]

    @type t :: %__MODULE__{direction: integer()}
  end

  defmodule Closed do
    @moduledoc "Payload for closing the active selector."
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule Confirmed do
    @moduledoc "Payload for confirming selector choice."
    defstruct [:selector, :item]

    @type t :: %__MODULE__{selector: term(), item: term()}
  end

  @spec opened(term()) :: Opened.t()
  def opened(selector), do: %Opened{selector: selector}

  @spec moved(integer()) :: Moved.t()
  def moved(direction) when is_integer(direction), do: %Moved{direction: direction}

  @spec closed() :: Closed.t()
  def closed, do: %Closed{}

  @spec confirmed(map() | keyword()) :: Confirmed.t()
  def confirmed(attrs \\ %{}), do: attrs |> Map.new() |> then(&struct(Confirmed, &1))
end
