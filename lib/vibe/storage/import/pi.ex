defmodule Vibe.Storage.Import.Pi do
  @moduledoc "Pi JSONL session importer."
  @behaviour Vibe.Storage.Importer

  alias Vibe.Event

  @impl true
  def source, do: :pi

  @impl true
  def import_path(path), do: import_path(path, [])

  @impl true
  def import_path(path, opts) do
    path = Path.expand(path)

    cond do
      File.dir?(path) -> import_dir(path, opts)
      File.regular?(path) -> import_file(path, file_opts(opts))
      true -> {:error, :not_found}
    end
  end

  defp import_dir(dir, opts) do
    files = dir |> Path.join("**/*.jsonl") |> Path.wildcard()
    total = length(files)
    progress(opts, %{phase: :scan, total: total})

    files
    |> Enum.with_index(1)
    |> Enum.reduce({0, 0, 0, []}, fn {file, index}, {count, skipped, event_count, errors} ->
      if imported?(file) do
        maybe_progress(opts, index, total, count, skipped + 1, event_count, errors)
        {count, skipped + 1, event_count, errors}
      else
        case import_file(file, file_opts(opts, index?: false)) do
          {:ok, result} ->
            event_count = event_count + result.events
            maybe_progress(opts, index, total, count + 1, skipped, event_count, errors)
            {count + 1, skipped, event_count, errors}

          {:error, reason} ->
            errors = [%{file: file, reason: inspect(reason)} | errors]
            maybe_progress(opts, index, total, count, skipped, event_count, errors)
            {count, skipped, event_count, errors}
        end
      end
    end)
    |> then(fn {count, skipped, event_count, errors} ->
      rebuild_fts = count > 0 and Keyword.get(opts, :rebuild_fts?, true)

      if rebuild_fts do
        progress(opts, %{phase: :fts_rebuild, imported: count, events: event_count})
        Vibe.Storage.FTS.rebuild(progress: Keyword.get(opts, :progress))
        progress(opts, %{phase: :fts_optimize})
        Vibe.Storage.FTS.optimize()
      end

      progress(opts, %{phase: :done, imported: count, skipped: skipped, events: event_count})

      {:ok,
       %{
         imported: count,
         skipped: skipped,
         events: event_count,
         fts_rebuilt: rebuild_fts,
         errors: Enum.reverse(errors)
       }}
    end)
  end

  defp import_file(file, opts) do
    with {:ok, header, count, events} <- parse_file(file) do
      session_id = Map.fetch!(header, "id")
      at = parse_datetime(header["timestamp"]) || DateTime.utc_now()
      Vibe.Session.Store.ensure_session(session_id, at, cwd: header["cwd"])

      :ok =
        Vibe.Session.Store.append_ui_events(Enum.reverse(events),
          index?: Keyword.get(opts, :index?, true)
        )

      Vibe.Storage.Import.record!(:pi, import_id(file), %{
        session_id: session_id,
        file: file,
        events: count
      })

      {:ok, %{session_id: session_id, events: count, file: file}}
    end
  end

  defp file_opts(opts, overrides \\ []) do
    opts
    |> Keyword.take([:index?])
    |> Keyword.merge(overrides)
  end

  defp maybe_progress(opts, index, total, imported, skipped, events, errors) do
    interval = Keyword.get(opts, :progress_interval, 50)

    if index == total or rem(index, interval) == 0 do
      progress(opts, %{
        phase: :import,
        current: index,
        total: total,
        imported: imported,
        skipped: skipped,
        events: events,
        errors: length(errors)
      })
    end
  end

  defp progress(opts, event) do
    case Keyword.get(opts, :progress) do
      fun when is_function(fun, 1) -> fun.(event)
      _progress -> :ok
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
    Enum.map_join(content, fn
      %{"type" => "text", "text" => text} -> text
      %{"text" => text} -> text
      part when is_binary(part) -> part
      part -> inspect(part)
    end)
  end

  defp content_text(nil), do: ""
  defp content_text(content), do: inspect(content)

  defp imported?(file), do: Vibe.Storage.Import.imported?(import_id(file))

  defp import_id(file), do: "pi:#{file}"

  defp parse_file(file) do
    file
    |> File.stream!(:line, [])
    |> Enum.reduce({nil, 0, []}, fn line, {header, count, events} ->
      case decode_line(line) do
        %{"type" => "session", "id" => id} = entry when is_binary(id) ->
          {entry, count, events}

        entry when is_map(entry) and not is_nil(header) ->
          {new_count, new_events} = import_entry(header["id"], {count, events}, entry)
          {header, new_count, new_events}

        _entry ->
          {header, count, events}
      end
    end)
    |> case do
      {nil, _count, _events} -> {:error, :missing_pi_session_header}
      {header, count, events} -> {:ok, header, count, events}
    end
  rescue
    exception -> {:error, exception}
  end

  defp decode_line(line) do
    case Jason.decode(line) do
      {:ok, map} when is_map(map) -> map
      _invalid -> nil
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> Vibe.Storage.normalize_datetime(dt)
      _invalid -> nil
    end
  end
end
