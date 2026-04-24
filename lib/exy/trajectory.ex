defmodule Exy.Trajectory do
  @moduledoc """
  Structured session event capture for self-improvement.
  """

  defstruct [:id, :session_id, :type, :at, :data]

  @type t :: %__MODULE__{
          id: String.t(),
          session_id: String.t() | nil,
          type: atom(),
          at: DateTime.t(),
          data: map()
        }

  @spec new(atom(), map(), keyword()) :: t()
  def new(type, data \\ %{}, opts \\ []) when is_atom(type) and is_map(data) do
    %__MODULE__{
      id: Keyword.get_lazy(opts, :id, &new_id/0),
      session_id: Keyword.get(opts, :session_id),
      type: type,
      at: Keyword.get_lazy(opts, :at, fn -> DateTime.utc_now() end),
      data: data
    }
  end

  defp new_id do
    12 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
