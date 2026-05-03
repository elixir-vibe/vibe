defmodule Exy.Files.ImageRef do
  @moduledoc "Durable reference to an image artifact stored outside inline JSON."

  @enforce_keys [:path, :mime_type]
  defstruct [:path, :mime_type, :filename, :size_bytes, :width, :height, :data]

  @type t :: %__MODULE__{
          path: Path.t(),
          mime_type: String.t(),
          filename: String.t() | nil,
          size_bytes: non_neg_integer() | nil,
          width: pos_integer() | nil,
          height: pos_integer() | nil,
          data: String.t() | nil
        }
end

defimpl Jason.Encoder, for: Exy.Files.ImageRef do
  def encode(ref, opts) do
    ref
    |> Map.from_struct()
    |> Map.delete(:data)
    |> Exy.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
