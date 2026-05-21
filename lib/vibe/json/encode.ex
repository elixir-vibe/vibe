defmodule Vibe.JSON.Encode do
  @moduledoc "JSON value normalization for Vibe domain encoders."

  alias Vibe.Model.Content

  @spec value(term()) :: term()
  def value(term) when is_boolean(term) or is_nil(term), do: term
  def value(term) when is_atom(term), do: Atom.to_string(term)

  def value(%DateTime{} = term), do: DateTime.to_iso8601(term)
  def value(%Date{} = term), do: Date.to_iso8601(term)

  def value(%Content.Text{} = term), do: %{type: "text", text: term.text}

  def value(%Content.Image{} = term) do
    %{
      type: "image",
      data: term.data,
      mime_type: term.mime_type,
      filename: term.filename,
      width: term.width,
      height: term.height
    }
  end

  def value(%_{} = term), do: term |> Map.from_struct() |> value()

  def value(term) when is_binary(term) do
    if String.valid?(term), do: term, else: %{type: "binary", data: Base.encode64(term)}
  end

  def value(term) when is_number(term), do: term

  def value(term) when is_tuple(term), do: term |> Tuple.to_list() |> value()
  def value(term) when is_list(term), do: Enum.map(term, &value/1)

  def value(term) when is_map(term) do
    Map.new(term, fn {key, value} -> {key(key), value(value)} end)
  rescue
    _exception -> inspect(term, limit: 50)
  end

  def value(term), do: inspect(term, limit: 50)

  @spec key(term()) :: String.t()
  def key(term) when is_atom(term), do: Atom.to_string(term)
  def key(term) when is_binary(term), do: term
  def key(term), do: to_string(term)
end
