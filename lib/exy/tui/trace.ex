defmodule Exy.TUI.Trace do
  @moduledoc "Internal implementation module."
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
    frames = frame_paths(dir)

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

  @spec audit(Path.t()) :: map()
  def audit(dir) do
    dir = Path.expand(dir)
    metadata = read_json(Path.join(dir, "metadata.json"))
    width = metadata["width"]
    height = metadata["height"]
    frames = frame_paths(dir)

    issues =
      []
      |> maybe_missing_trace(dir)
      |> maybe_missing_frames(frames)
      |> audit_frames(frames, width, height)

    %{
      dir: dir,
      ok?: issues == [],
      frames: length(frames),
      issues: Enum.reverse(issues)
    }
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

  defp frame_paths(dir), do: Path.wildcard(Path.join([Path.expand(dir), "frames", "*.txt"]))

  defp maybe_missing_trace(issues, dir) do
    if File.exists?(Path.join(dir, "trace.jsonl")) do
      issues
    else
      [issue(:error, :missing_trace, "trace.jsonl is missing") | issues]
    end
  end

  defp maybe_missing_frames(issues, []),
    do: [issue(:error, :missing_frames, "no frame snapshots were captured") | issues]

  defp maybe_missing_frames(issues, _frames), do: issues

  defp audit_frames(issues, frames, width, height) do
    frames
    |> Enum.with_index(1)
    |> Enum.reduce(issues, fn {path, index}, issues ->
      path
      |> File.read!()
      |> audit_frame(index, width, height, issues)
    end)
  end

  defp audit_frame(text, index, width, height, issues) do
    lines = String.split(text, "\n")

    issues
    |> audit_frame_height(index, lines, height)
    |> audit_line_widths(index, lines, width)
    |> audit_prompt_regions(index, lines)
    |> audit_adjacent_duplicates(index, lines)
  end

  defp audit_frame_height(issues, _index, _lines, height) when not is_integer(height), do: issues

  defp audit_frame_height(issues, index, lines, height) do
    if length(lines) > height do
      [
        issue(:warning, :frame_height, "frame has more lines than terminal height", index)
        | issues
      ]
    else
      issues
    end
  end

  defp audit_line_widths(issues, _index, _lines, width) when not is_integer(width), do: issues

  defp audit_line_widths(issues, index, lines, width) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce(issues, fn {line, line_number}, issues ->
      visible_width = Width.visible_length(line)

      if visible_width > width do
        message = "line width #{visible_width} exceeds terminal width #{width}"
        [issue(:error, :line_width, message, index, line_number) | issues]
      else
        issues
      end
    end)
  end

  defp audit_prompt_regions(issues, index, lines) do
    prompt_tops = matching_line_indexes(lines, &String.contains?(&1, " Prompt "))
    prompt_bottoms = matching_line_indexes(lines, &prompt_bottom?/1)

    issues
    |> audit_single_prompt(index, prompt_tops)
    |> audit_prompt_bottom(index, prompt_tops, prompt_bottoms)
    |> audit_content_below_prompt(index, lines, prompt_bottoms)
  end

  defp audit_single_prompt(issues, index, prompt_tops) do
    if length(prompt_tops) > 1 do
      [issue(:error, :duplicate_prompt, "multiple prompt boxes are visible", index) | issues]
    else
      issues
    end
  end

  defp audit_prompt_bottom(issues, index, [_top | _rest], []),
    do: [
      issue(:error, :prompt_region, "prompt box top is visible without a bottom", index) | issues
    ]

  defp audit_prompt_bottom(issues, _index, _prompt_tops, _prompt_bottoms), do: issues

  defp audit_content_below_prompt(issues, index, lines, prompt_bottoms) do
    case List.last(prompt_bottoms) do
      nil ->
        issues

      bottom_index ->
        content_below? =
          lines
          |> Enum.drop(bottom_index + 1)
          |> Enum.any?(&(String.trim(&1) != ""))

        if content_below? do
          [
            issue(:error, :content_below_prompt, "non-blank content appears below prompt", index)
            | issues
          ]
        else
          issues
        end
    end
  end

  defp audit_adjacent_duplicates(issues, index, lines) do
    lines
    |> Enum.map(&String.trim/1)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(1)
    |> Enum.reduce(issues, fn {[left, right], line_number}, issues ->
      if duplicate_content_line?(left, right) do
        message = "adjacent duplicate visible line: #{String.slice(left, 0, 60)}"
        [issue(:warning, :adjacent_duplicate, message, index, line_number) | issues]
      else
        issues
      end
    end)
  end

  defp duplicate_content_line?(left, right) do
    left == right and Width.visible_length(left) >= 12 and not border_line?(left)
  end

  defp border_line?(line), do: String.match?(line, ~r/^[╭╮╰╯─│\s]+$/u)

  defp prompt_bottom?(line), do: String.contains?(line, "╰") and String.contains?(line, "─")

  defp matching_line_indexes(lines, fun) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} -> fun.(line) end)
    |> Enum.map(fn {_line, index} -> index end)
  end

  defp issue(severity, check, message, frame \\ nil, line \\ nil) do
    %{severity: severity, check: check, message: message, frame: frame, line: line}
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
