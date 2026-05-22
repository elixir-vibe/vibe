defmodule Vibe.Event.Notification do
  @moduledoc "Typed semantic notification event payloads."

  defmodule Added do
    @moduledoc "Payload for adding a transient notification."
    @enforce_keys [:text]
    defstruct [:id, :text, :ttl_ms, level: :info]

    @type t :: %__MODULE__{
            id: String.t() | nil,
            text: String.t(),
            ttl_ms: non_neg_integer() | nil,
            level: atom()
          }
  end

  defmodule Expired do
    @moduledoc "Payload for expiring a transient notification."
    @enforce_keys [:id]
    defstruct [:id]

    @type t :: %__MODULE__{id: String.t()}
  end

  @spec added(map() | keyword()) :: Added.t()
  def added(attrs), do: attrs |> Map.new() |> then(&struct!(Added, &1))

  @spec expired(String.t()) :: Expired.t()
  def expired(id) when is_binary(id), do: %Expired{id: id}
end
