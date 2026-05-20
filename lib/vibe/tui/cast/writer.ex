defmodule Vibe.TUI.Cast.Writer do
  @moduledoc """
  Writer process for native Vibe TUI cast recordings.

  The writer stores exact terminal output bytes in independently compressed ETF
  blocks and writes a sidecar index on close. Calls are synchronous so bytes are
  persisted before the runtime writes the same data to the terminal.
  """

  use GenServer

  alias Vibe.TUI.Cast

  @max_block_events 100
  @max_block_bytes 256_000
  @idx_suffix ".idx.etf.gz"

  defstruct [
    :path,
    :file,
    :header,
    :started_at,
    :compression,
    block_seq: 0,
    block_events: [],
    block_bytes: 0,
    blocks: []
  ]

  @type t :: %__MODULE__{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec output(pid() | nil, IO.chardata()) :: :ok
  def output(nil, _iodata), do: :ok

  def output(pid, iodata),
    do: GenServer.call(pid, {:event, {:output, IO.iodata_to_binary(iodata)}})

  @spec input(pid() | nil, IO.chardata()) :: :ok
  def input(nil, _iodata), do: :ok
  def input(pid, iodata), do: GenServer.call(pid, {:event, {:input, IO.iodata_to_binary(iodata)}})

  @spec input_redacted(pid() | nil, non_neg_integer()) :: :ok
  def input_redacted(nil, _byte_count), do: :ok

  def input_redacted(pid, byte_count),
    do: GenServer.call(pid, {:event, {:input_redacted, byte_count}})

  @spec key(pid() | nil, term()) :: :ok
  def key(nil, _event), do: :ok
  def key(pid, event), do: GenServer.call(pid, {:event, {:key, event}})

  @spec resize(pid() | nil, pos_integer(), pos_integer()) :: :ok
  def resize(nil, _columns, _rows), do: :ok
  def resize(pid, columns, rows), do: GenServer.call(pid, {:event, {:resize, columns, rows}})

  @spec app_event(pid() | nil, term()) :: :ok
  def app_event(nil, _event), do: :ok
  def app_event(pid, event), do: GenServer.call(pid, {:event, {:app_event, event}})

  @spec trace_frame(pid() | nil, term()) :: :ok
  def trace_frame(nil, _payload), do: :ok
  def trace_frame(pid, payload), do: GenServer.call(pid, {:event, {:trace_frame, payload}})

  @spec trace_snapshot(pid() | nil, term()) :: :ok
  def trace_snapshot(nil, _payload), do: :ok
  def trace_snapshot(pid, payload), do: GenServer.call(pid, {:event, {:trace_snapshot, payload}})

  @spec close(pid() | nil) :: :ok
  def close(nil), do: :ok
  def close(pid), do: GenServer.call(pid, :close, :infinity)

  @spec write_index(Path.t(), map(), [map()]) :: :ok | {:error, term()}
  def write_index(path, header, blocks) do
    index = %{
      format: :vibe_tui_cast_index,
      version: 1,
      recording: path,
      header: header,
      blocks: Enum.map(blocks, &block_index/1),
      app_events: indexed_events(blocks, :app_event),
      trace_frames: indexed_events(blocks, :trace_frame),
      trace_snapshots: indexed_events(blocks, :trace_snapshot)
    }

    (path <> @idx_suffix)
    |> File.write(:zlib.gzip(:erlang.term_to_binary(index)))
  end

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    File.mkdir_p!(Path.dirname(path))

    compression = compression(opts)
    started_at = System.monotonic_time(:microsecond)

    header = %{
      format: :vibe_tui_cast,
      version: Cast.version(),
      started_at_unix_ms: System.system_time(:millisecond),
      width: Keyword.fetch!(opts, :width),
      height: Keyword.fetch!(opts, :height),
      cwd: Keyword.get_lazy(opts, :cwd, &File.cwd!/0),
      session_id: Keyword.get(opts, :session_id),
      commit: commit(),
      term: System.get_env("TERM"),
      env: %{TERM: System.get_env("TERM") || ""},
      input_recorded?: input_recorded?(opts),
      contains_conversation?: true,
      compression: compression,
      event_encoding: :erlang_external_term_format
    }

    with {:ok, file} <- File.open(path, [:write, :binary]) do
      header_binary = :erlang.term_to_binary(header)

      IO.binwrite(file, [
        Cast.magic(),
        <<Cast.version()::16, byte_size(header_binary)::32>>,
        header_binary
      ])

      {:ok,
       %__MODULE__{
         path: path,
         file: file,
         header: header,
         started_at: started_at,
         compression: compression
       }}
    end
  end

  @impl true
  def handle_call({:event, event}, _from, state) do
    state = append_event(state, timestamp_event(state, event))
    {:reply, :ok, maybe_flush(state)}
  end

  def handle_call(:close, _from, state) do
    state = flush_block(state)
    File.close(state.file)
    :ok = write_index(state.path, state.header, Enum.reverse(state.blocks))
    {:stop, :normal, :ok, state}
  end

  @impl true
  def terminate(_reason, %{file: file} = state) do
    state = flush_block(state)
    File.close(file)
    write_index(state.path, state.header, Enum.reverse(state.blocks))
    :ok
  rescue
    _error -> :ok
  end

  defp timestamp_event(state, {:output, bytes}), do: {:output, elapsed_us(state), bytes}
  defp timestamp_event(state, {:input, bytes}), do: {:input, elapsed_us(state), bytes}

  defp timestamp_event(state, {:input_redacted, byte_count}),
    do: {:input_redacted, elapsed_us(state), byte_count}

  defp timestamp_event(state, {:key, event}), do: {:key, elapsed_us(state), simplify_key(event)}

  defp timestamp_event(state, {:resize, columns, rows}),
    do: {:resize, elapsed_us(state), columns, rows}

  defp timestamp_event(state, {:app_event, event}),
    do: {:app_event, elapsed_us(state), sanitize_event(event)}

  defp timestamp_event(state, {:trace_frame, payload}),
    do: {:trace_frame, elapsed_us(state), payload}

  defp timestamp_event(state, {:trace_snapshot, payload}),
    do: {:trace_snapshot, elapsed_us(state), payload}

  defp append_event(state, event) do
    %{
      state
      | block_events: [event | state.block_events],
        block_bytes: state.block_bytes + event_size(event)
    }
  end

  defp maybe_flush(state) do
    if length(state.block_events) >= @max_block_events or state.block_bytes >= @max_block_bytes do
      flush_block(state)
    else
      state
    end
  end

  defp flush_block(%{block_events: []} = state), do: state

  defp flush_block(state) do
    events = Enum.reverse(state.block_events)
    {start_t_us, end_t_us} = Enum.reduce(events, {nil, nil}, &time_range/2)

    block = %{
      block: state.block_seq,
      start_t_us: start_t_us,
      end_t_us: end_t_us,
      width: state.header.width,
      height: state.header.height,
      events: events
    }

    binary = Cast.encode_block(block, state.compression)
    offset = :file.position(state.file, :cur) |> elem(1)
    IO.binwrite(state.file, [<<byte_size(binary)::32>>, binary])

    indexed_block =
      block
      |> Map.put(:offset, offset)
      |> Map.put(:length, byte_size(binary) + 4)

    %{
      state
      | block_seq: state.block_seq + 1,
        block_events: [],
        block_bytes: 0,
        blocks: [indexed_block | state.blocks]
    }
  end

  defp compression(opts) do
    cond do
      Keyword.get(opts, :gzip) == false -> :none
      System.get_env("VIBE_TUI_CAST_GZIP") == "0" -> :none
      true -> :gzip
    end
  end

  defp input_recorded?(opts),
    do: Keyword.get(opts, :record_input, System.get_env("VIBE_TUI_CAST_INPUT") == "1")

  defp commit do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {hash, 0} -> String.trim(hash)
      _other -> nil
    end
  rescue
    _error -> nil
  end

  defp elapsed_us(state), do: System.monotonic_time(:microsecond) - state.started_at

  defp event_size({_kind, _t_us, binary}) when is_binary(binary), do: byte_size(binary)
  defp event_size(event), do: :erlang.external_size(event)

  defp time_range(event, {nil, nil}) do
    time = event_time(event)
    {time, time}
  end

  defp time_range(event, {min_time, max_time}) do
    time = event_time(event)
    {min(min_time, time), max(max_time, time)}
  end

  defp event_time({_kind, t_us, _payload}), do: t_us
  defp event_time({_kind, t_us, _a, _b}), do: t_us

  defp simplify_key(%Ghostty.KeyEvent{} = event) do
    %{key: event.key, mods: event.mods, action: event.action, utf8: event.utf8}
  end

  defp simplify_key(event), do: event

  defp sanitize_event(%{id: id, type: type, session_id: session_id}) do
    %{id: id, type: type, session_id: session_id}
  end

  defp sanitize_event(%{type: type}), do: %{type: type}
  defp sanitize_event(event) when is_atom(event), do: event
  defp sanitize_event(event), do: inspect(event)

  defp block_index(block) do
    %{
      block: block.block,
      offset: block.offset,
      length: block.length,
      start_t_us: block.start_t_us,
      end_t_us: block.end_t_us,
      event_count: length(block.events),
      output_count: Enum.count(block.events, &(elem(&1, 0) == :output)),
      dimensions: {block.width, block.height}
    }
  end

  defp indexed_events(blocks, kind) do
    blocks
    |> Enum.flat_map(fn block ->
      block.events
      |> Enum.filter(&(elem(&1, 0) == kind))
      |> Enum.map(fn event -> indexed_event(block, event) end)
    end)
  end

  defp indexed_event(block, {kind, t_us, payload}) do
    %{kind: kind, t_us: t_us, block: block.block, payload: payload}
  end
end
