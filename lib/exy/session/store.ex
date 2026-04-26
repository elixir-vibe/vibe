defmodule Exy.Session.Store do
  @moduledoc """
  Durable JSONL sessions for dialogs, tool events, and usage.
  """

  alias Exy.Trajectory
  alias Exy.UI.{Event, Reducer, State}

  @event_types %{
    "assistant_aborted" => :assistant_aborted,
    "assistant_delta" => :assistant_delta,
    "assistant_message_added" => :assistant_message_added,
    "assistant_stream_finished" => :assistant_stream_finished,
    "assistant_stream_started" => :assistant_stream_started,
    "assistant_thinking_delta" => :assistant_thinking_delta,
    "context_compaction_failed" => :context_compaction_failed,
    "context_compaction_finished" => :context_compaction_finished,
    "context_compaction_started" => :context_compaction_started,
    "hidden_thinking_label_updated" => :hidden_thinking_label_updated,
    "messages_cleared" => :messages_cleared,
    "model_selected" => :model_selected,
    "notification_added" => :notification_added,
    "notification_expired" => :notification_expired,
    "overlay_closed" => :overlay_closed,
    "overlay_opened" => :overlay_opened,
    "patch_confirmation_requested" => :patch_confirmation_requested,
    "plugin_status_cleared" => :plugin_status_cleared,
    "plugin_status_updated" => :plugin_status_updated,
    "plugin_widget_cleared" => :plugin_widget_cleared,
    "plugin_widget_updated" => :plugin_widget_updated,
    "prompt_submitted" => :prompt_submitted,
    "selector_closed" => :selector_closed,
    "selector_confirmed" => :selector_confirmed,
    "selector_moved" => :selector_moved,
    "selector_opened" => :selector_opened,
    "session_new_requested" => :session_new_requested,
    "session_selected" => :session_selected,
    "slash_command_submitted" => :slash_command_submitted,
    "status_changed" => :status_changed,
    "title_updated" => :title_updated,
    "tool_finished" => :tool_finished,
    "tool_started" => :tool_started,
    "tool_toggled" => :tool_toggled,
    "truncation_toggled" => :truncation_toggled,
    "usage_updated" => :usage_updated,
    "user_message_added" => :user_message_added,
    "working_message_updated" => :working_message_updated
  }

  @trajectory_types %{
    "assistant_message" => :assistant_message,
    "compaction" => :compaction,
    "llm_usage" => :llm_usage,
    "self_patch_reloaded" => :self_patch_reloaded,
    "subagent_finished" => :subagent_finished,
    "subagent_started" => :subagent_started,
    "tool_call" => :tool_call,
    "user_message" => :user_message
  }

  @spec new_id() :: String.t()
  def new_id do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    now <> "-" <> suffix
  end

  @spec dir() :: String.t()
  def dir do
    Exy.Paths.sessions_dir()
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

  @spec append_trajectory(atom(), map(), keyword()) :: Trajectory.t()
  def append_trajectory(type, data \\ %{}, opts \\ []) do
    event = Trajectory.new(type, data, opts)
    _ = append(event)
    event
  end

  @spec trajectory(keyword()) :: [Trajectory.t()]
  def trajectory(opts \\ []) do
    opts
    |> trajectory_events()
    |> maybe_filter_trajectory(
      Keyword.get(opts, :type),
      &(&1.type == Keyword.fetch!(opts, :type))
    )
    |> take_trajectory(Keyword.get(opts, :limit, :infinity))
  end

  @spec append(Trajectory.t()) :: :ok | {:error, term()}
  def append(%Trajectory{session_id: nil} = event),
    do: append(%{event | session_id: "__global__"})

  def append(%Trajectory{} = event) do
    with :ok <- File.mkdir_p(dir()),
         line <- Jason.encode!(Map.put(encode_event(event), "entry_type", "trajectory")) <> "\n" do
      File.write(path(event.session_id), line, [:append])
    end
  end

  @spec events(String.t()) :: [Trajectory.t()]
  def events(session_id) when is_binary(session_id) do
    session_id
    |> path()
    |> read_trajectory_events_file()
  end

  @spec all_events() :: [Trajectory.t()]
  def all_events do
    case File.ls(dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
        |> Enum.flat_map(fn file -> dir() |> Path.join(file) |> read_trajectory_events_file() end)
        |> Enum.sort_by(& &1.at, DateTime)

      {:error, _reason} ->
        []
    end
  end

  @spec clear() :: :ok
  def clear do
    case File.ls(dir()) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          if String.ends_with?(file, ".jsonl"), do: File.rm(Path.join(dir(), file))
        end)

      {:error, _reason} ->
        :ok
    end

    :ok
  end

  @spec append_eval_state(Code.binding(), Macro.Env.t(), keyword()) :: :ok | {:error, term()}
  def append_eval_state(binding, %Macro.Env{} = env, opts) when is_list(binding) do
    session_id = Keyword.fetch!(opts, :session_id)

    with :ok <- File.mkdir_p(dir()),
         {:ok, entry} <- eval_state_entry(session_id, binding, env),
         line <- Jason.encode!(entry) <> "\n" do
      File.write(path(session_id), line, [:append])
    end
  end

  @spec eval_state(String.t()) :: %{binding: Code.binding(), env: Macro.Env.t()} | nil
  def eval_state(session_id) when is_binary(session_id) do
    session_id
    |> path()
    |> read_eval_state_file()
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

  defp trajectory_events(opts) do
    case Keyword.get(opts, :session_id) do
      session_id when is_binary(session_id) -> events(session_id)
      _session_id -> all_events()
    end
  end

  defp maybe_filter_trajectory(events, nil, _fun), do: events
  defp maybe_filter_trajectory(events, _value, fun), do: Enum.filter(events, fun)

  defp take_trajectory(events, :infinity), do: events
  defp take_trajectory(events, limit), do: Enum.take(events, limit)

  defp session_info(file) do
    full_path = Path.join(dir(), file)
    stat = File.stat!(full_path, time: :posix)
    id = Path.rootname(file)
    events = ui_events(id)
    state = id |> restore_state(events) |> finalize_restored_state()
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

  defp finalize_restored_state(%{status: :working} = state) do
    has_active_stream? = not is_nil(state.streaming_message)

    has_running_tool? =
      Enum.any?(state.pending_tools, fn {_id, tool} -> Map.get(tool, :status) == :running end)

    if has_active_stream? or has_running_tool?, do: state, else: %{state | status: :idle}
  end

  defp finalize_restored_state(state), do: state

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

  defp eval_state_entry(session_id, binding, env) do
    snapshot = %{binding: binding, env: env}

    {:ok,
     %{
       "entry_type" => "eval_state",
       "session_id" => session_id,
       "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "state" => snapshot |> :erlang.term_to_binary() |> Base.encode64()
     }}
  rescue
    exception -> {:error, exception}
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

  defp read_trajectory_events_file(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&decode_trajectory_line/1)

      {:error, :enoent} ->
        []
    end
  end

  defp read_eval_state_file(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.reduce(nil, &decode_eval_state_line/2)

      {:error, :enoent} ->
        nil
    end
  end

  defp read_ui_events_file(path) do
    case File.read(path) do
      {:ok, text} ->
        lines = String.split(text, "\n", trim: true)
        ui_events = Enum.flat_map(lines, &decode_ui_event_line/1)

        case ui_events do
          [] -> lines |> Enum.flat_map(&decode_trajectory_line/1) |> project_trajectory_events()
          events -> events
        end

      {:error, :enoent} ->
        []
    end
  end

  defp ui_event_paths(session_id) do
    [ui_events_path(session_id)]
  end

  defp decode_eval_state_line(line, acc) do
    with {:ok, %{"entry_type" => "eval_state", "state" => encoded}} <- Jason.decode(line),
         {:ok, state} <- decode_eval_state(encoded) do
      state
    else
      _ -> acc
    end
  end

  defp decode_eval_state(encoded) do
    with {:ok, binary} <- Base.decode64(encoded),
         %{binding: binding, env: %Macro.Env{} = env} <- :erlang.binary_to_term(binary, [:safe]) do
      {:ok, %{binding: binding, env: env}}
    else
      _ -> :error
    end
  rescue
    _exception -> :error
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
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_event_type(map["type"]) do
      {:ok,
       {map["seq"],
        Event.new(type, map["session_id"], atomize(map["data"] || %{}),
          id: map["id"],
          at: at
        )}}
    end
  rescue
    _exception -> :error
  end

  defp decode_event(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_trajectory_type(map["type"]) do
      {:ok,
       Trajectory.new(type, atomize(map["data"] || %{}),
         id: map["id"],
         session_id: map["session_id"],
         at: at
       )}
    end
  rescue
    _exception -> :error
  end

  defp project_trajectory_events(events) do
    events
    |> Enum.flat_map(&project_trajectory_event/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {event, seq} -> {seq, event} end)
  end

  defp project_trajectory_event(%Trajectory{
         type: :user_message,
         session_id: session_id,
         at: at,
         data: data
       }) do
    text = Map.get(data, :prompt, "")
    [Event.new(:user_message_added, session_id, %{text: text}, at: at)]
  end

  defp project_trajectory_event(%Trajectory{
         type: :assistant_message,
         session_id: session_id,
         at: at,
         data: data
       }) do
    payload =
      if Map.has_key?(data, :error),
        do: %{error: Map.get(data, :error)},
        else: %{result: Map.get(data, :result) || data}

    [Event.new(:assistant_message_added, session_id, payload, at: at)]
  end

  defp project_trajectory_event(%Trajectory{
         type: :llm_usage,
         session_id: session_id,
         at: at,
         data: data
       }) do
    [Event.new(:usage_updated, session_id, data, at: at)]
  end

  defp project_trajectory_event(_event), do: []

  defp decode_event_type(type) when is_binary(type), do: Map.fetch(@event_types, type)
  defp decode_event_type(_type), do: :error

  defp decode_trajectory_type(type) when is_binary(type), do: Map.fetch(@trajectory_types, type)
  defp decode_trajectory_type(_type), do: :error

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

  defp atomize(%{"$atom" => value}) when is_binary(value) do
    case safe_existing_atom(value) do
      {:ok, atom} -> atom
      :error -> value
    end
  end

  defp atomize(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {atomize_key(key), atomize(value)} end)
  end

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(value), do: value

  defp atomize_key(key) when is_binary(key) do
    case safe_existing_atom(key) do
      {:ok, atom} -> atom
      :error -> key
    end
  end

  defp atomize_key(key), do: key

  defp safe_existing_atom(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
