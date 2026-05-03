defimpl Jason.Encoder, for: Tuple do
  @moduledoc "Encodes tuples as JSON arrays for tool outputs and telemetry payloads."

  def encode(tuple, opts) do
    tuple
    |> Exy.JSON.Encode.value()
    |> Jason.Encode.list(opts)
  end
end
