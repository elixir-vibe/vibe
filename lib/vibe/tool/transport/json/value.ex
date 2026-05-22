defmodule Vibe.Tool.Transport.JSON.Value do
  @moduledoc false

  @spec value(term()) :: term()
  def value(value) when is_boolean(value) or is_nil(value), do: value
  def value(value) when is_atom(value), do: Atom.to_string(value)
  def value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def value(%Date{} = value), do: Date.to_iso8601(value)

  def value(%Vibe.Model.Content.Text{} = value), do: %{type: "text", text: value.text}

  def value(%Vibe.Model.Content.Image{} = value) do
    Map.new([
      {:type, "image"},
      {:data, value.data},
      {:mime_type, value.mime_type},
      {:filename, value.filename},
      {:width, value.width},
      {:height, value.height}
    ])
  end

  def value(%Vibe.Files.ImageRef{} = value),
    do: value |> Map.from_struct() |> Map.delete(:data) |> value()

  def value(%Vibe.Files.ReadResult{} = value),
    do: value |> Map.from_struct() |> Map.delete(:__content_parts__) |> value()

  def value(%Vibe.Image{} = value), do: value |> Map.from_struct() |> value()
  def value(%Vibe.UI.Error{} = value), do: value |> Map.from_struct() |> value()

  def value(%_{} = value) do
    raise ArgumentError,
          "no tool transport JSON projection for #{inspect(value.__struct__)}; add a Vibe.Tool.Transport.JSON.Encodable implementation"
  end

  def value(value) when is_binary(value) do
    if String.valid?(value), do: value, else: %{type: "binary", data: Base.encode64(value)}
  end

  def value(value) when is_number(value), do: value
  def value(value) when is_tuple(value), do: value |> Tuple.to_list() |> value()
  def value(value) when is_list(value), do: Enum.map(value, &value/1)

  def value(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {key(key), value(value)} end)
  end

  def value(value) do
    raise ArgumentError,
          "no tool transport JSON projection for #{inspect(value)}; add a Vibe.Tool.Transport.JSON.Encodable implementation"
  end

  @spec key(term()) :: String.t()
  def key(term) when is_atom(term), do: Atom.to_string(term)
  def key(term) when is_binary(term), do: term
  def key(term), do: to_string(term)
end
