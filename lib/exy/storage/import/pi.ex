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
    |> Path.join("**/*.jsonl")
    |> Path.wildcard()
    |> Enum.reduce({0, 0, []}, fn file, {count, skipped, errors} ->
      if imported?(file) do
        {count, skipped + 1, errors}
      else
        case import_file(file) do
          {:ok, _result} ->
            {count + 1, skipped, errors}

          {:error, reason} ->
            {count, skipped, [%{file: file, reason: inspect(reason)} | errors]}
        end
      end
    end)
    |> then(fn {count, skipped, errors} ->
      {:ok, %{imported: count, skipped: skipped, errors: Enum.reverse(errors)}}
    end)
  end

  defp import_file(file) do
    with {:ok, entries} <- read_jsonl(file),
         {:ok, header} <- header(entries) do
      session_id = Map.fetch!(header, "id")
      at = parse_datetime(header["timestamp"]) || DateTime.utc_now()
      Exy.Session.Store.ensure_session(session_id, at, cwd: header["cwd"])

      {count, events} =
        entries
        |> Enum.reject(&(Map.get(&1, "type") == "session"))
        |> Enum.reduce({0, []}, fn entry, acc -> import_entry(session_id, acc, entry) end)

      :ok = Exy.Session.Store.append_ui_events(Enum.reverse(events))

      Exy.Storage.Import.record!(:pi, import_id(file), %{
        session_id: session_id,
        file: file,
        events: count
      })

      {:ok, %{session_id: session_id, events: count, file: file}}
    end
  end

  defp import_entry(
         session_id,
         {seq, events},
         %{"type" => "message", "message" => %{"role" => role} = message} = entry
       ) do
    event_type = if role == "user", do: :user_message_added, else: :assistant_message_added
    data = message_data(event_type, message, role)
    event = build_event(session_id, seq + 1, event_type, data, entry["timestamp"])
    {seq + 1, [{seq + 1, event} | events]}
  end

  defp import_entry(session_id, {seq, events}, %{"type" => "model_change"} = entry) do
    model = [entry["provider"], entry["modelId"]] |> Enum.reject(&is_nil/1) |> Enum.join(":")
    event = build_event(session_id, seq + 1, :model_selected, %{model: model}, entry["timestamp"])
    {seq + 1, [{seq + 1, event} | events]}
  end

  defp import_entry(
         session_id,
         {seq, events},
         %{"type" => "session_info", "name" => name} = entry
       ) do
    event = build_event(session_id, seq + 1, :title_updated, %{title: name}, entry["timestamp"])
    {seq + 1, [{seq + 1, event} | events]}
  end

  defp import_entry(
         session_id,
         {seq, events},
         %{"type" => "compaction", "summary" => summary} = entry
       ) do
    event =
      build_event(
        session_id,
        seq + 1,
        :context_compaction_finished,
        %{summary: summary},
        entry["timestamp"]
      )

    {seq + 1, [{seq + 1, event} | events]}
  end

  defp import_entry(_session_id, acc, _entry), do: acc

  defp build_event(session_id, seq, type, data, timestamp) do
    at = parse_datetime(timestamp) || DateTime.utc_now()
    Event.new(type, session_id, data, id: "pi-#{session_id}-#{seq}", at: at)
  end

  defp message_data(:user_message_added, message, _role),
    do: %{text: content_text(message["content"])}

  defp message_data(:assistant_message_added, message, "toolResult"),
    do: %{text: content_text(message["content"]), import_role: "tool"}

  defp message_data(:assistant_message_added, message, _role),
    do: %{text: assistant_text(message["content"])}

  defp assistant_text(content) when is_list(content) do
    content
    |> Enum.filter(fn
      %{"type" => "text"} -> true
      part when is_binary(part) -> true
      _part -> false
    end)
    |> content_text()
  end

  defp assistant_text(content), do: content_text(content)

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

  defp imported?(file), do: Exy.Storage.Import.imported?(import_id(file))

  defp import_id(file), do: "pi:#{file}"

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
