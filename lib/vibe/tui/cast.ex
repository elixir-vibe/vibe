defmodule Vibe.TUI.Cast do
  @moduledoc """
  Native terminal recording and replay for Vibe TUI sessions.

  Recordings store exact terminal output bytes in chunked Erlang External Term
  Format blocks, gzip-compressed by default. The native format keeps Vibe-only
  events such as keys and resizes while `export_asciinema/2` produces a
  standard asciinema v2 `.cast` file from the same output stream.
  """

  alias Ghostty.Terminal
  alias Vibe.TUI.Cast.Format
  alias Vibe.TUI.Cast.Writer

  @magic Format.magic()
  @version Format.version()
  @default_scrollback 20_000

  defstruct [:path, :header, :blocks, :events]

  @type event ::
          {:output, non_neg_integer(), binary()}
          | {:input, non_neg_integer(), binary()}
          | {:input_redacted, non_neg_integer(), non_neg_integer()}
          | {:key, non_neg_integer(), term()}
          | {:resize, non_neg_integer(), pos_integer(), pos_integer()}
          | {:app_event, non_neg_integer(), term()}
          | {:trace_frame, non_neg_integer(), term()}
          | {:trace_snapshot, non_neg_integer(), term()}

  @type t :: %__MODULE__{path: Path.t(), header: map(), blocks: [map()], events: [event()]}

  @doc "Starts a native cast writer unless recording is disabled."
  @spec start_writer(keyword()) :: {:ok, pid() | nil} | {:error, term()}
  def start_writer(opts) do
    case path_from_opts(opts) do
      nil -> {:ok, nil}
      path -> Writer.start_link(Keyword.put(opts, :path, path))
    end
  end

  @doc "Returns the path configured by CLI opts or environment variables."
  @spec path_from_opts(keyword()) :: String.t() | nil
  def path_from_opts(opts) do
    cond do
      path = Keyword.get(opts, :cast) -> path
      path = System.get_env("VIBE_TUI_CAST") -> path
      dir = System.get_env("VIBE_TUI_CAST_DIR") -> Path.join(dir, generated_name(opts))
      true -> nil
    end
  end

  @doc "Opens a native Vibe TUI cast file."
  @spec open(Path.t() | t()) :: {:ok, t()} | {:error, term()}
  def open(%__MODULE__{} = cast), do: {:ok, cast}

  def open(path) when is_binary(path) do
    with {:ok, binary} <- File.read(path),
         {:ok, header, blocks} <- decode(binary) do
      events = Enum.flat_map(blocks, &Map.fetch!(&1, :events))
      {:ok, %__MODULE__{path: path, header: header, blocks: blocks, events: events}}
    end
  end

  @doc "Opens a native cast file and raises on failure."
  @spec open!(Path.t() | t()) :: t()
  def open!(%__MODULE__{} = cast), do: cast

  def open!(path) do
    case open(path) do
      {:ok, cast} -> cast
      {:error, reason} -> raise "cannot open TUI cast #{inspect(path)}: #{inspect(reason)}"
    end
  end

  @doc "Returns summary information about a cast."
  @spec info(Path.t() | t()) :: map()
  def info(path_or_cast) do
    cast = open!(path_or_cast)
    header = cast.header
    duration_us = cast.events |> Enum.map(&event_time/1) |> Enum.max(fn -> 0 end)

    %{
      path: cast.path,
      version: Map.get(header, :version),
      width: Map.get(header, :width),
      height: Map.get(header, :height),
      session_id: Map.get(header, :session_id),
      cwd: Map.get(header, :cwd),
      started_at_unix_ms: Map.get(header, :started_at_unix_ms),
      duration_ms: div(duration_us, 1_000),
      blocks: length(cast.blocks),
      events: length(cast.events),
      output_events: count_events(cast.events, :output),
      input_recorded?: Map.get(header, :input_recorded?, false),
      compression: Map.get(header, :compression, :gzip)
    }
  end

  @doc "Returns all decoded native events."
  @spec events(Path.t() | t()) :: [event()]
  def events(path_or_cast), do: path_or_cast |> open!() |> Map.fetch!(:events)

  @doc "Returns a terminal snapshot at a time or semantic point."
  @spec snapshot(Path.t() | t(), keyword()) :: {:ok, binary() | map()} | {:error, term()}
  def snapshot(path_or_cast, opts \\ []) do
    cast = open!(path_or_cast)
    format = Keyword.get(opts, :format, :plain)
    target_us = target_time_us(cast, opts)
    max_scrollback = Keyword.get(opts, :max_scrollback, @default_scrollback)

    with {:ok, terminal} <-
           Terminal.start_link(
             cols: Map.fetch!(cast.header, :width),
             rows: Map.fetch!(cast.header, :height),
             max_scrollback: max_scrollback
           ) do
      try do
        replay_until(cast.events, terminal, target_us)
        terminal_snapshot(terminal, format)
      after
        if Process.alive?(terminal), do: GenServer.stop(terminal)
      end
    end
  end

  @doc "Returns a terminal snapshot or raises."
  @spec snapshot!(Path.t() | t(), keyword()) :: binary() | map()
  def snapshot!(path_or_cast, opts \\ []) do
    case snapshot(path_or_cast, opts) do
      {:ok, snapshot} -> snapshot
      {:error, reason} -> raise "cannot snapshot TUI cast: #{inspect(reason)}"
    end
  end

  @doc "Finds times where a plain terminal snapshot contains text or a regex match."
  @spec find(Path.t() | t(), binary() | Regex.t(), keyword()) :: [
          %{time_ms: non_neg_integer(), match: binary()}
        ]
  def find(path_or_cast, pattern, opts \\ []) do
    cast = open!(path_or_cast)
    every_ms = Keyword.get(opts, :every_ms, 250)
    duration_us = cast.events |> Enum.map(&event_time/1) |> Enum.max(fn -> 0 end)

    duration_ms = ceil_div(duration_us, 1_000)

    0..duration_ms//every_ms
    |> Enum.concat([duration_ms])
    |> Enum.uniq()
    |> Enum.flat_map(fn time_ms ->
      text = snapshot!(cast, time_ms: time_ms, format: :plain)

      if visual_match?(text, pattern) do
        [%{time_ms: time_ms, match: match_text(text, pattern)}]
      else
        []
      end
    end)
  end

  @doc "Exports a native recording to asciinema v2 JSONL format."
  @spec export_asciinema(Path.t() | t(), Path.t()) :: :ok | {:error, term()}
  def export_asciinema(path_or_cast, output_path) do
    cast = open!(path_or_cast)
    File.mkdir_p!(Path.dirname(output_path))

    header = %{
      version: 2,
      width: Map.fetch!(cast.header, :width),
      height: Map.fetch!(cast.header, :height),
      timestamp: div(Map.get(cast.header, :started_at_unix_ms, unix_ms()), 1_000),
      env: asciinema_env(cast.header)
    }

    lines = [Jason.encode!(header) | asciinema_events(cast)]
    File.write(output_path, Enum.intersperse(lines, "\n"))
  end

  @doc "Rebuilds the sidecar index for a native recording."
  @spec reindex(Path.t()) :: :ok | {:error, term()}
  def reindex(path) do
    with {:ok, cast} <- open(path) do
      Writer.write_index(path, cast.header, cast.blocks)
    end
  end

  @doc "Returns the native cast file magic bytes."
  defdelegate magic, to: Format

  @doc "Returns the native cast format version."
  defdelegate version, to: Format

  @doc "Encodes a native cast block with the configured compression."
  defdelegate encode_block(term, compression), to: Format

  @doc "Decodes a native cast block with the configured compression."
  defdelegate decode_block(binary, compression), to: Format

  defp generated_name(opts) do
    session_id = Keyword.get(opts, :session_id, "session")
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    "#{timestamp}-#{session_id}.vibe-tui.etf.gz"
  end

  defp decode(<<@magic, @version::16, header_len::32, rest::binary>>) do
    case rest do
      <<header_binary::binary-size(header_len), blocks_binary::binary>> ->
        header = :erlang.binary_to_term(header_binary, [:safe])
        compression = Map.fetch!(header, :compression)
        first_block_offset = byte_size(@magic) + 2 + 4 + header_len
        {:ok, blocks} = decode_blocks(blocks_binary, compression, first_block_offset, [])
        {:ok, header, blocks}

      _other ->
        {:error, :truncated_header}
    end
  end

  defp decode(<<@magic, version::16, _rest::binary>>),
    do: {:error, {:unsupported_version, version}}

  defp decode(_binary), do: {:error, :invalid_magic}

  defp decode_blocks(<<>>, _compression, _offset, blocks), do: {:ok, Enum.reverse(blocks)}

  defp decode_blocks(<<len::32, rest::binary>>, compression, offset, blocks) do
    case rest do
      <<block_binary::binary-size(len), remaining::binary>> ->
        block =
          block_binary
          |> decode_block(compression)
          |> Map.put_new(:offset, offset)
          |> Map.put_new(:length, len + 4)

        decode_blocks(remaining, compression, offset + len + 4, [block | blocks])

      _other ->
        {:error, :truncated_block}
    end
  end

  defp count_events(events, kind) do
    Enum.count(events, fn event -> elem(event, 0) == kind end)
  end

  defp event_time({_kind, t_us, _payload}), do: t_us
  defp event_time({_kind, t_us, _a, _b}), do: t_us

  defp target_time_us(cast, opts) do
    cond do
      time_us = Keyword.get(opts, :time_us) -> time_us
      time_ms = Keyword.get(opts, :time_ms) -> time_ms * 1_000
      time = Keyword.get(opts, :time) -> trunc(time * 1_000_000)
      frame = Keyword.get(opts, :frame) -> index_time(cast, :trace_frame, frame)
      snapshot = Keyword.get(opts, :snapshot) -> index_time(cast, :trace_snapshot, snapshot)
      true -> cast.events |> Enum.map(&event_time/1) |> Enum.max(fn -> 0 end)
    end
  end

  defp index_time(cast, kind, seq) do
    cast.events
    |> Enum.find_value(0, fn
      {^kind, t_us, %{seq: ^seq}} -> t_us
      {^kind, t_us, %{frame: ^seq}} -> t_us
      {^kind, t_us, %{snapshot: ^seq}} -> t_us
      _event -> nil
    end)
  end

  defp replay_until(events, terminal, target_us) do
    events
    |> Enum.take_while(&(event_time(&1) <= target_us))
    |> Enum.each(fn
      {:output, _t_us, bytes} -> Terminal.write(terminal, bytes)
      {:resize, _t_us, columns, rows} -> Terminal.resize(terminal, columns, rows)
      _event -> :ok
    end)
  end

  defp terminal_snapshot(terminal, :plain), do: Terminal.snapshot(terminal, :plain)
  defp terminal_snapshot(terminal, :html), do: Terminal.snapshot(terminal, :html)
  defp terminal_snapshot(terminal, :vt), do: Terminal.snapshot(terminal, :vt)

  defp terminal_snapshot(terminal, :cells) do
    {:ok,
     %{
       cells: Terminal.cells(terminal),
       cursor: Terminal.cursor_state(terminal),
       scrollbar: Terminal.scrollbar(terminal),
       size: Terminal.size(terminal)
     }}
  end

  defp visual_match?(text, pattern) when is_binary(pattern), do: String.contains?(text, pattern)
  defp visual_match?(text, %Regex{} = pattern), do: Regex.match?(pattern, text)

  defp match_text(_text, pattern) when is_binary(pattern), do: pattern

  defp match_text(text, %Regex{} = pattern) do
    case Regex.run(pattern, text) do
      [match | _] -> match
      _ -> ""
    end
  end

  defp asciinema_env(header) do
    header
    |> Map.get(:env, %{})
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp asciinema_events(cast) do
    cast.events
    |> Enum.flat_map(fn
      {:output, t_us, bytes} -> [Jason.encode!([seconds(t_us), "o", bytes])]
      {:input, t_us, bytes} -> [Jason.encode!([seconds(t_us), "i", bytes])]
      _event -> []
    end)
  end

  defp seconds(t_us), do: t_us / 1_000_000
  defp ceil_div(value, divisor), do: div(value + divisor - 1, divisor)
  defp unix_ms, do: System.system_time(:millisecond)
end
