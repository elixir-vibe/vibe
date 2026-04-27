defmodule Exy.TUI.Trace do
  @moduledoc false

  alias Exy.TUI.Width

  defstruct [:dir, :started_at, seq: 0]

  @type t :: %__MODULE__{dir: Path.t(), started_at: integer(), seq: non_neg_integer()}

  @spec summary(Path.t()) :: map()
  def summary(dir) do
    dir = Path.expand(dir)
    entries = entries(dir)
    frames = Path.wildcard(Path.join([dir, "frames", "*.txt"]))
    snapshots = Path.wildcard(Path.join([dir, "snapshots", "*.json"]))

    %{
      dir: dir,
      metadata: read_json(Path.join(dir, "metadata.json")),
      entries: length(entries),
      frames: length(frames),
      snapshots: length(snapshots),
      first_entry: List.first(entries),
      last_entry: List.last(entries)
    }
  end

  @spec entries(Path.t()) :: [map()]
  def entries(dir) do
    path = Path.join(Path.expand(dir), "trace.jsonl")

    if File.exists?(path) do
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Enum.map(&Jason.decode!/1)
    else
      []
    end
  end

  @spec frame(Path.t(), pos_integer() | :last) :: {:ok, String.t()} | {:error, term()}
  def frame(dir, index \\ :last) do
    frames = Path.wildcard(Path.join([Path.expand(dir), "frames", "*.txt"]))

    path =
      case index do
        :last -> List.last(frames)
        index when is_integer(index) -> Enum.at(frames, index - 1)
      end

    case path do
      nil -> {:error, :frame_not_found}
      path -> File.read(path)
    end
  end

  @spec start(keyword()) :: t() | nil
  def start(opts) do
    case Keyword.get(opts, :trace_dir) do
      nil ->
        nil

      false ->
        nil

      dir ->
        dir = Path.expand(to_string(dir))
        File.mkdir_p!(Path.join(dir, "frames"))
        File.mkdir_p!(Path.join(dir, "snapshots"))

        trace = %__MODULE__{dir: dir, started_at: System.monotonic_time(:microsecond)}
        write_metadata(trace, opts)
        trace
    end
  end

  require Exy.Debug

  @spec record(t() | nil, atom(), term()) :: t() | nil
  def record(trace, type, payload \\ %{})
  def record(nil, _type, _payload), do: nil

  def record(%__MODULE__{} = trace, type, payload) do
    seq = trace.seq + 1
    trace = %{trace | seq: seq}

    entry = %{
      seq: seq,
      t_us: elapsed_us(trace),
      type: type,
      payload: sanitize(payload)
    }

    append_jsonl(Path.join(trace.dir, "trace.jsonl"), entry)
    trace
  end

  @spec frame(t() | nil, [IO.chardata()], term()) :: t() | nil
  def frame(nil, _lines, _reason), do: nil

  def frame(%__MODULE__{} = trace, lines, reason) do
    seq = trace.seq + 1
    trace = %{trace | seq: seq}
    name = seq |> Integer.to_string() |> String.pad_leading(5, "0")
    path = Path.join([trace.dir, "frames", name <> ".txt"])

    text = Enum.map_join(lines, "\n", &Width.visible_text/1)
    File.write!(path, text)

    entry = %{
      seq: seq,
      t_us: elapsed_us(trace),
      type: :frame,
      payload: %{reason: sanitize(reason), path: Path.relative_to(path, trace.dir)}
    }

    append_jsonl(Path.join(trace.dir, "trace.jsonl"), entry)
    trace
  end

  @spec snapshot(t() | nil, term(), term()) :: t() | nil
  def snapshot(nil, _snapshot, _reason), do: nil

  def snapshot(%__MODULE__{} = trace, snapshot, reason) do
    seq = trace.seq + 1
    trace = %{trace | seq: seq}
    name = seq |> Integer.to_string() |> String.pad_leading(5, "0")
    path = Path.join([trace.dir, "snapshots", name <> ".json"])

    File.write!(path, Jason.encode!(sanitize(snapshot), pretty: true))

    entry = %{
      seq: seq,
      t_us: elapsed_us(trace),
      type: :snapshot,
      payload: %{reason: sanitize(reason), path: Path.relative_to(path, trace.dir)}
    }

    append_jsonl(Path.join(trace.dir, "trace.jsonl"), entry)
    trace
  end

  defp read_json(path) do
    if File.exists?(path), do: path |> File.read!() |> Jason.decode!(), else: %{}
  end

  defp write_metadata(trace, opts) do
    metadata = %{
      started_at_unix_ms: System.system_time(:millisecond),
      exy_commit: git_commit(),
      elixir: System.version(),
      otp: System.otp_release(),
      cwd: File.cwd!(),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height),
      session_id: Keyword.get(opts, :session_id),
      compile_time_debug: Exy.Debug.enabled?()
    }

    File.write!(Path.join(trace.dir, "metadata.json"), Jason.encode!(metadata, pretty: true))
  end

  defp append_jsonl(path, entry), do: File.write!(path, [Jason.encode!(entry), "\n"], [:append])

  defp elapsed_us(trace), do: System.monotonic_time(:microsecond) - trace.started_at

  defp git_commit do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {commit, 0} -> String.trim(commit)
      _result -> nil
    end
  end

  defp sanitize(%Ghostty.KeyEvent{} = event) do
    event
    |> Map.from_struct()
    |> sanitize()
  end

  defp sanitize(%_struct{} = value), do: value |> Map.from_struct() |> sanitize()

  defp sanitize(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {sanitize_key(key), sanitize(value)} end)
  end

  defp sanitize(list) when is_list(list) do
    if Keyword.keyword?(list), do: sanitize(Map.new(list)), else: Enum.map(list, &sanitize/1)
  end

  defp sanitize(binary) when is_binary(binary) do
    if String.valid?(binary), do: binary, else: Base.encode64(binary)
  end

  defp sanitize(atom) when is_atom(atom), do: atom
  defp sanitize(number) when is_number(number), do: number
  defp sanitize(pid) when is_pid(pid), do: inspect(pid)
  defp sanitize(reference) when is_reference(reference), do: inspect(reference)
  defp sanitize(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> sanitize()
  defp sanitize(value), do: inspect(value)

  defp sanitize_key(key) when is_atom(key), do: key
  defp sanitize_key(key) when is_binary(key), do: key
  defp sanitize_key(key), do: inspect(key)
end
