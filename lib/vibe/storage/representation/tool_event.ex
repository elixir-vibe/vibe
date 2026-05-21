defmodule Vibe.Storage.Representation.ToolEvent do
  @moduledoc "Current storage representation for `Vibe.Tool.Event`."

  @enforce_keys []
  defstruct [
    :id,
    :name,
    :args,
    :output,
    :output_format,
    :output_parts,
    :output_truncation,
    :status,
    :phase
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: atom() | String.t() | nil,
          args: term(),
          output: term(),
          output_format: atom() | nil,
          output_parts: [map()] | nil,
          output_truncation: :head | :tail | nil,
          status: Vibe.Tool.Event.status() | nil,
          phase: atom() | nil
        }

  @spec decode!(map()) :: t()
  def decode!(tool) when is_map(tool) do
    tool = atomize_keys(tool)

    struct(
      __MODULE__,
      tool
      |> Map.take([
        :id,
        :name,
        :args,
        :output,
        :output_format,
        :output_parts,
        :output_truncation,
        :status,
        :phase
      ])
      |> Map.update(:name, nil, &decode_atom/1)
      |> Map.update(:output_format, nil, &decode_atom/1)
      |> Map.update(:output_truncation, nil, &decode_atom/1)
      |> Map.update(:status, nil, &decode_atom/1)
      |> Map.update(:phase, nil, &decode_atom/1)
      |> Map.update(:output, nil, &decode_output/1)
    )
  end

  defp decode_output(%{parts: parts} = output) when is_list(parts) do
    output
    |> Map.update(:image, nil, &decode_image_ref/1)
    |> Map.put(:parts, Enum.map(parts, &decode_content_part/1))
  end

  defp decode_output(output), do: output

  defp decode_content_part(%{type: type, text: text})
       when type in ["text", :text] and is_binary(text),
       do: Vibe.Model.Content.text(text)

  defp decode_content_part(%{type: type, data: data, mime_type: mime_type} = part)
       when type in ["image", :image] and is_binary(data) and is_binary(mime_type) do
    Vibe.Model.Content.image(
      data: data,
      mime_type: mime_type,
      filename: Map.get(part, :filename),
      width: Map.get(part, :width),
      height: Map.get(part, :height)
    )
  end

  defp decode_content_part(part), do: part

  defp decode_image_ref(%{path: path, mime_type: mime_type} = image)
       when is_binary(path) and is_binary(mime_type) do
    struct(
      Vibe.Files.ImageRef,
      Map.take(image, [:path, :mime_type, :filename, :size_bytes, :width, :height])
    )
  end

  defp decode_image_ref(image), do: image

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {decode_atom(key), atomize_keys(value)}
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp decode_atom(value) when is_atom(value), do: value

  defp decode_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  defp decode_atom(value), do: value
end

defimpl Vibe.Storage.Persistable, for: Vibe.Tool.Event do
  def persist(event) do
    %Vibe.Storage.Representation.ToolEvent{
      id: event.id,
      name: event.name,
      args: event.args,
      output: strip_transient_content_parts(event.output),
      output_format: event.output_format,
      output_parts: event.output_parts,
      output_truncation: event.output_truncation,
      status: event.status,
      phase: event.phase
    }
  end

  defp strip_transient_content_parts(%{} = output) do
    output
    |> Map.delete(:__content_parts__)
    |> Map.delete("__content_parts__")
  end

  defp strip_transient_content_parts(output), do: output
end

defimpl Vibe.Storage.Restorable, for: Vibe.Storage.Representation.ToolEvent do
  def restore(event) do
    %Vibe.Tool.Event{
      id: event.id,
      name: event.name,
      args: event.args,
      output: event.output,
      output_format: event.output_format,
      output_parts: event.output_parts,
      output_truncation: event.output_truncation,
      status: event.status,
      phase: event.phase
    }
  end
end

defimpl Jason.Encoder, for: Vibe.Storage.Representation.ToolEvent do
  def encode(event, opts) do
    event
    |> Map.from_struct()
    |> Vibe.Storage.JSON.value()
    |> Jason.Encode.map(opts)
  end
end
