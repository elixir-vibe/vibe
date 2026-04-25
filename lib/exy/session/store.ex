defmodule Exy.Session.Store do
  @moduledoc """
  Durable JSONL sessions for dialogs, tool events, and usage.
  """

  alias Exy.Trajectory
  alias Exy.UI.{Event, Reducer, State}

  @spec new_id() :: String.t()
  def new_id do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    now <> "-" <> suffix
  end

  @spec dir() :: String.t()
  def dir do
    (System.get_env("EXY_SESSION_DIR") ||
       Application.get_env(:exy, :session_dir, "~/.exy/sessions"))
    |> Path.expand()
  end

  @spec path(String.t()) :: String.t()
  def path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".jsonl")
  end

  @spec log_path(String.t()) :: String.t()
  def log_path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".log")
  end

  @spec ui_events_path(String.t()) :: String.t()
  def ui_events_path(session_id) when is_binary(session_id), do: path(session_id)

  @spec legacy_ui_events_path(String.t()) :: String.t()
  def legacy_ui_events_path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".events.jsonl")
  end

  @spec append(Trajectory.t()) :: :ok | {:error, term()}
  def append(%Trajectory{session_id: nil}), do: :ok

  def append(%Trajectory{} = event) do
    with :ok <- File.mkdir_p(dir()),
         line <- Jason.encode!(Map.put(encode_event(event), "entry_type", "trajectory")) <> "\n" do
      File.write(path(event.session_id), line, [:append])
    end
  end

  @spec events(String.t()) :: [Trajectory.t()]
  def events(session_id) when is_binary(session_id) do
    case File.read(path(session_id)) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&decode_trajectory_line/1)

      {:error, :enoent} ->
        []
    end
  end

  @spec append_ui_event(Event.t(), non_neg_integer()) :: :ok | {:error, term()}
  def append_ui_event(%Event{} = event, seq) do
    with :ok <- File.mkdir_p(dir()),
         line <-
           Jason.encode!(Map.put(encode_ui_event(event, seq), "entry_type", "ui_event")) <> "\n" do
      File.write(ui_events_path(event.session_id), line, [:append])
    end
  end

  @spec ui_events(String.t()) :: [{non_neg_integer(), Event.t()}]
  def ui_events(session_id) when is_binary(session_id) do
    session_id
    |> ui_event_paths()
    |> Enum.flat_map(&read_ui_events_file/1)
    |> Enum.sort_by(fn {seq, _event} -> seq || 0 end)
  end

  @spec ui_events_after(String.t(), non_neg_integer()) :: [{non_neg_integer(), Event.t()}]
  def ui_events_after(session_id, seq) when is_binary(session_id) and is_integer(seq) do
    session_id
    |> ui_events()
    |> Enum.filter(fn {event_seq, _event} -> event_seq > seq end)
  end

  @spec info(String.t()) :: map() | nil
  def info(session_id) when is_binary(session_id) do
    file = safe_session_id(session_id) <> ".jsonl"
    full_path = path(session_id)

    if File.exists?(full_path) do
      session_info(file)
    end
  end

  @spec list() :: [map()]
  def list do
    case File.ls(dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
        |> Enum.reject(&String.ends_with?(&1, ".events.jsonl"))
        |> Enum.map(&session_info/1)
        |> Enum.sort_by(&DateTime.to_unix(&1.updated_at), :desc)

      {:error, _reason} ->
        []
    end
  end

  defp session_info(file) do
    full_path = Path.join(dir(), file)
    stat = File.stat!(full_path, time: :posix)
    id = Path.rootname(file)
    events = ui_events(id)
    state = restore_state(id, events)
    messages = Enum.reject(state.messages, &match?(%{streaming?: true}, &1))
    first_user = Enum.find(messages, &(&1[:role] == :user))
    last_message = List.last(messages)

    %{
      id: id,
      path: full_path,
      size: stat.size,
      created_at: created_at(events),
      updated_at: DateTime.from_unix!(stat.mtime),
      message_count: length(messages),
      first_message: Exy.Session.Preview.message(first_user),
      last_message_preview: Exy.Session.Preview.message(last_message),
      status: state.status,
      model: state.model,
      usage: state.usage
    }
  end

  defp restore_state(session_id, events) do
    events
    |> Enum.map(fn {_seq, event} -> event end)
    |> then(&Reducer.apply_events(State.new(session_id: session_id), &1))
  end

  defp created_at([]), do: nil
  defp created_at([{_seq, %Event{at: at}} | _events]), do: at

  defp encode_event(%Trajectory{} = event) do
    %{
      "id" => event.id,
      "session_id" => event.session_id,
      "type" => Atom.to_string(event.type),
      "at" => DateTime.to_iso8601(event.at),
      "data" => json_safe(event.data)
    }
  end

  defp encode_ui_event(%Event{} = event, seq) do
    %{
      "seq" => seq,
      "id" => event.id,
      "session_id" => event.session_id,
      "type" => Atom.to_string(event.type),
      "at" => DateTime.to_iso8601(event.at),
      "data" => json_safe(event.data)
    }
  end

  defp read_ui_events_file(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&decode_ui_event_line/1)

      {:error, :enoent} ->
        []
    end
  end

  defp ui_event_paths(session_id) do
    [ui_events_path(session_id), legacy_ui_events_path(session_id)]
    |> Enum.uniq()
  end

  defp decode_ui_event_line(line) do
    with {:ok, %{"entry_type" => "ui_event"} = map} <- Jason.decode(line),
         {:ok, event} <- decode_ui_event(map) do
      [event]
    else
      _ -> []
    end
  end

  defp decode_trajectory_line(line) do
    with {:ok, map} <- Jason.decode(line),
         true <- Map.get(map, "entry_type", "trajectory") == "trajectory",
         {:ok, event} <- decode_event(map) do
      [event]
    else
      _ -> []
    end
  end

  defp decode_ui_event(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]) do
      {:ok,
       {map["seq"],
        Event.new(String.to_atom(map["type"]), map["session_id"], atomize(map["data"] || %{}),
          id: map["id"],
          at: at
        )}}
    end
  end

  defp decode_event(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]) do
      {:ok,
       Trajectory.new(String.to_atom(map["type"]), atomize(map["data"] || %{}),
         id: map["id"],
         session_id: map["session_id"],
         at: at
       )}
    end
  end

  defp json_safe(value) when is_atom(value), do: %{"$atom" => Atom.to_string(value)}

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value), do: value

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {to_string(key), json_safe(value)} end)
  rescue
    _exception -> inspect(value, limit: 50)
  end

  defp json_safe(value), do: inspect(value, limit: 50)

  defp atomize(%{"$atom" => value}) when is_binary(value), do: String.to_atom(value)

  defp atomize(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {String.to_atom(key), atomize(value)} end)

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(value), do: value

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
