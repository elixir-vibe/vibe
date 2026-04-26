defmodule Exy.Storage.Import.Pi do
  @moduledoc false

  @behaviour Exy.Storage.Importer

  alias Exy.UI.Event

  @impl true
  def source, do: :pi

  @impl true
  def import_path(path) do
    path = Path.expand(path)

    cond do
      File.dir?(path) -> import_dir(path)
      File.regular?(path) -> import_file(path)
      true -> {:error, :not_found}
    end
  end

  defp import_dir(dir) do
    dir
    |> Path.join("*.jsonl")
    |> Path.wildcard()
    |> Enum.reduce({0, []}, fn file, {count, errors} ->
      case import_file(file) do
        {:ok, _result} -> {count + 1, errors}
        {:error, reason} -> {count, [%{file: file, reason: inspect(reason)} | errors]}
      end
    end)
    |> then(fn {count, errors} -> {:ok, %{imported: count, errors: Enum.reverse(errors)}} end)
  end

  defp import_file(file) do
    with {:ok, entries} <- read_jsonl(file),
         {:ok, header} <- header(entries) do
      session_id = Map.fetch!(header, "id")
      at = parse_datetime(header["timestamp"]) || DateTime.utc_now()
      Exy.Session.Store.ensure_session(session_id, at)
      Exy.Storage.Import.record!(:pi, "pi:#{file}", %{session_id: session_id, file: file})

      entries
      |> Enum.reject(&(Map.get(&1, "type") == "session"))
      |> Enum.reduce(0, fn entry, seq -> import_entry(session_id, seq, entry) end)
      |> then(&{:ok, %{session_id: session_id, events: &1, file: file}})
    end
  end

  defp import_entry(
         session_id,
         seq,
         %{"type" => "message", "message" => %{"role" => role} = message} = entry
       ) do
    event_type = if role == "user", do: :user_message_added, else: :assistant_message_added
    data = message_data(event_type, message)
    append_event(session_id, seq + 1, event_type, data, entry["timestamp"])
  end

  defp import_entry(session_id, seq, %{"type" => "model_change"} = entry) do
    model = [entry["provider"], entry["modelId"]] |> Enum.reject(&is_nil/1) |> Enum.join(":")
    append_event(session_id, seq + 1, :model_selected, %{model: model}, entry["timestamp"])
  end

  defp import_entry(session_id, seq, %{"type" => "session_info", "name" => name} = entry) do
    append_event(session_id, seq + 1, :title_updated, %{title: name}, entry["timestamp"])
  end

  defp import_entry(session_id, seq, %{"type" => "compaction", "summary" => summary} = entry) do
    append_event(
      session_id,
      seq + 1,
      :context_compaction_finished,
      %{summary: summary},
      entry["timestamp"]
    )
  end

  defp import_entry(_session_id, seq, _entry), do: seq

  defp append_event(session_id, seq, type, data, timestamp) do
    at = parse_datetime(timestamp) || DateTime.utc_now()
    event = Event.new(type, session_id, data, id: "pi-#{session_id}-#{seq}", at: at)
    :ok = Exy.Session.Store.append_ui_event(event, seq)
    seq
  end

  defp message_data(:user_message_added, message), do: %{text: content_text(message["content"])}

  defp message_data(:assistant_message_added, message),
    do: %{text: content_text(message["content"])}

  defp content_text(content) when is_binary(content), do: content

  defp content_text(content) when is_list(content) do
    Enum.map_join(content, "", fn
      %{"type" => "text", "text" => text} -> text
      %{"text" => text} -> text
      part when is_binary(part) -> part
      part -> inspect(part)
    end)
  end

  defp content_text(nil), do: ""
  defp content_text(content), do: inspect(content)

  defp read_jsonl(file) do
    case File.read(file) do
      {:ok, text} ->
        entries =
          text
          |> String.split("\n", trim: true)
          |> Enum.flat_map(fn line ->
            case Jason.decode(line) do
              {:ok, map} when is_map(map) -> [map]
              _invalid -> []
            end
          end)

        {:ok, entries}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp header(entries) do
    case Enum.find(entries, &(Map.get(&1, "type") == "session" and is_binary(Map.get(&1, "id")))) do
      nil -> {:error, :missing_pi_session_header}
      header -> {:ok, header}
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> Exy.Storage.normalize_datetime(dt)
      _invalid -> nil
    end
  end
end
