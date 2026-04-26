defmodule Exy.Session.Store do
  @moduledoc """
  Durable JSONL sessions for dialogs, tool events, and usage.
  """

  alias Exy.Session.Store.{Codec, Listing}
  alias Exy.Trajectory
  alias Exy.UI.Event

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
         line <-
           Jason.encode!(Map.put(Codec.encode_trajectory(event), "entry_type", "trajectory")) <>
             "\n" do
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
         {:ok, entry} <- Codec.eval_state_entry(session_id, binding, env),
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
           Jason.encode!(Map.put(Codec.encode_ui_event(event, seq), "entry_type", "ui_event")) <>
             "\n" do
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
  def info(session_id) when is_binary(session_id), do: Listing.info(session_id)

  @spec list() :: [map()]
  def list, do: Listing.list()

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

  defp read_trajectory_events_file(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&Codec.decode_trajectory_line/1)

      {:error, :enoent} ->
        []
    end
  end

  defp read_eval_state_file(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n", trim: true)
        |> Enum.reduce(nil, &Codec.decode_eval_state_line/2)

      {:error, :enoent} ->
        nil
    end
  end

  defp read_ui_events_file(path) do
    case File.read(path) do
      {:ok, text} ->
        lines = String.split(text, "\n", trim: true)
        ui_events = Enum.flat_map(lines, &Codec.decode_ui_event_line/1)

        case ui_events do
          [] ->
            lines
            |> Enum.flat_map(&Codec.decode_trajectory_line/1)
            |> Codec.project_trajectory_events()

          events ->
            events
        end

      {:error, :enoent} ->
        []
    end
  end

  defp ui_event_paths(session_id) do
    [ui_events_path(session_id)]
  end

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
