defmodule Vibe.UI.Event do
  @moduledoc """
  UI-neutral event emitted by Vibe sessions.

  TUI and Phoenix LiveView clients consume these events and reduce them into the
  same state. Events should describe Vibe semantics, not terminal rendering.
  """

  @enforce_keys [:id, :type, :session_id, :at, :data]
  defstruct [:id, :type, :session_id, :at, :data]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          session_id: String.t(),
          at: DateTime.t(),
          data: map()
        }

  @spec new(atom(), String.t(), map(), keyword()) :: t()
  def new(type, session_id, data \\ %{}, opts \\ [])
      when is_atom(type) and is_binary(session_id) and is_map(data) do
    %__MODULE__{
      id: Keyword.get_lazy(opts, :id, &new_id/0),
      type: type,
      session_id: session_id,
      at: Keyword.get_lazy(opts, :at, fn -> DateTime.utc_now() end),
      data: data
    }
  end

  defp new_id do
    12 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end

defimpl Jason.Encoder, for: Vibe.UI.Event do
  def encode(event, opts) do
    %{
      id: event.id,
      session_id: event.session_id,
      type: event.type,
      at: event.at,
      data: event.data
    }
    |> Vibe.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
