defmodule Vibe.Telemetry do
  @moduledoc """
  Local telemetry recorder and introspection API for Vibe.

  Vibe stores sanitized telemetry events in the local SQLite database so agents
  can inspect their own runtime without requiring an external collector.
  """

  use GenServer

  import Ecto.Query

  alias Vibe.Storage.Schema.TelemetryEvent

  @handler_id "vibe-telemetry-recorder"
  @req_llm_otel_handler_id "vibe-req-llm-open-telemetry"
  @max_recent 500

  @decode_keys %{
    "action" => :action,
    "alarm_id" => :alarm_id,
    "alarm_type" => :alarm_type,
    "command" => :command,
    "description" => :description,
    "duration" => :duration,
    "error" => :error,
    "event_type" => :event_type,
    "measurements" => :measurements,
    "metadata" => :metadata,
    "model" => :model,
    "operation" => :operation,
    "provider" => :provider,
    "request" => :request,
    "request_id" => :request_id,
    "session_id" => :session_id,
    "status" => :status,
    "system_time" => :system_time,
    "total_tokens" => :total_tokens,
    "type" => :type,
    "usage" => :usage
  }

  @events [
    [:vibe, :session, :command, :start],
    [:vibe, :session, :command, :stop],
    [:vibe, :session, :command, :exception],
    [:vibe, :plugin, :load, :start],
    [:vibe, :plugin, :load, :stop],
    [:vibe, :plugin, :load, :exception],
    [:vibe, :plugin, :dispatch, :start],
    [:vibe, :plugin, :dispatch, :stop],
    [:vibe, :plugin, :dispatch, :exception],
    [:vibe, :system, :alarm, :set],
    [:vibe, :system, :alarm, :clear],
    [:req_llm, :request, :start],
    [:req_llm, :request, :stop],
    [:req_llm, :request, :exception],
    [:req_llm, :reasoning, :start],
    [:req_llm, :reasoning, :update],
    [:req_llm, :reasoning, :stop],
    [:req_llm, :token_usage],
    [:jido, :action, :start],
    [:jido, :action, :stop],
    [:jido, :agent, :cmd, :start],
    [:jido, :agent, :cmd, :stop],
    [:jido, :agent, :cmd, :exception],
    [:jido, :agent_server, :signal, :start],
    [:jido, :agent_server, :signal, :stop],
    [:jido, :agent_server, :signal, :exception],
    [:jido, :agent_server, :directive, :start],
    [:jido, :agent_server, :directive, :stop],
    [:jido, :agent_server, :directive, :exception],
    [:jido, :agent_server, :queue, :overflow],
    [:jido, :signal, :bus, :before_dispatch],
    [:jido, :signal, :bus, :after_dispatch],
    [:jido, :signal, :bus, :dispatch_skipped],
    [:jido, :signal, :bus, :dispatch_error],
    [:jido, :signal, :bus, :backpressure],
    [:jido, :dispatch, :start],
    [:jido, :dispatch, :stop],
    [:jido, :dispatch, :exception],
    [:finch, :request, :start],
    [:finch, :request, :stop],
    [:finch, :request, :exception],
    [:finch, :queue, :start],
    [:finch, :queue, :stop],
    [:finch, :queue, :exception],
    [:finch, :connect, :start],
    [:finch, :connect, :stop],
    [:finch, :send, :start],
    [:finch, :send, :stop],
    [:finch, :recv, :start],
    [:finch, :recv, :stop],
    [:finch, :recv, :exception],
    [:websockex, :connected],
    [:websockex, :disconnected],
    [:websockex, :terminate],
    [:websockex, :frame, :received],
    [:websockex, :frame, :sent]
  ]

  defstruct recent: [], attached?: false, req_llm_otel?: false

  @type event :: %{
          required(:event) => [atom()],
          required(:measurements) => map(),
          required(:metadata) => map(),
          required(:at) => String.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec events() :: [[atom()]]
  def events, do: @events

  @spec path() :: String.t()
  def path, do: Vibe.Paths.database() |> Path.expand()

  @spec recent(pos_integer()) :: [event()]
  def recent(limit \\ 50) when is_integer(limit) and limit > 0,
    do: GenServer.call(__MODULE__, {:recent, limit})

  @spec all(keyword()) :: [event()]
  def all(opts \\ []) do
    limit = Keyword.get(opts, :limit, :infinity)

    Vibe.Storage.ensure!()

    query =
      case limit do
        :infinity ->
          order_by(TelemetryEvent, [event], event.id)

        limit when is_integer(limit) ->
          TelemetryEvent
          |> order_by([event], desc: event.id)
          |> limit(^limit)
      end

    query
    |> Vibe.Repo.all()
    |> Enum.map(&decode_record/1)
    |> maybe_reverse_limited(limit)
  end

  @spec summary(keyword()) :: map()
  def summary(opts \\ []) do
    events = all(opts)

    %{
      path: path(),
      count: length(events),
      by_event: Enum.frequencies_by(events, &Enum.join(&1.event, ".")),
      recent: Enum.take(events, -10)
    }
  end

  @spec clear() :: :ok | {:error, term()}
  def clear do
    GenServer.call(__MODULE__, :clear)
  catch
    :exit, _reason -> {:error, :telemetry_unavailable}
  end

  @doc "Intentional facade for the public Vibe API boundary."
  @spec execute([atom()], map(), map()) :: :ok
  defdelegate execute(event, measurements \\ %{}, metadata \\ %{}), to: :telemetry

  @spec span([atom()], map(), (-> result)) :: result when result: term()
  def span(event_prefix, metadata, fun)
      when is_list(event_prefix) and is_map(metadata) and is_function(fun, 0) do
    :telemetry.span(event_prefix, metadata, fn -> {fun.(), metadata} end)
  end

  @impl true
  def init(_opts) do
    attached? = attach_recorder()
    req_llm_otel? = attach_req_llm_open_telemetry()
    {:ok, %__MODULE__{attached?: attached?, req_llm_otel?: req_llm_otel?}}
  end

  @impl true
  def handle_call({:recent, limit}, _from, state) do
    {:reply, state.recent |> Enum.reverse() |> Enum.take(limit), state}
  end

  def handle_call(:clear, _from, state) do
    Vibe.Storage.ensure!()
    Vibe.Repo.delete_all(TelemetryEvent)
    {:reply, :ok, %{state | recent: []}}
  end

  @impl true
  def handle_cast({:telemetry_event, event_name, measurements, metadata}, state) do
    event = build_event(event_name, measurements, metadata)
    _ = append_event(event)
    {:noreply, %{state | recent: remember(state.recent, event)}}
  end

  def handle_cast(_message, state), do: {:noreply, state}

  defp attach_recorder do
    :telemetry.detach(@handler_id)

    case :telemetry.attach_many(@handler_id, @events, &__MODULE__.handle_event/4, self()) do
      :ok -> true
      {:error, :already_exists} -> true
    end
  rescue
    _exception -> false
  end

  defp attach_req_llm_open_telemetry do
    if Code.ensure_loaded?(ReqLLM.OpenTelemetry) do
      case ReqLLM.OpenTelemetry.attach(@req_llm_otel_handler_id) do
        :ok -> true
        {:error, :already_exists} -> true
        {:error, _reason} -> false
      end
    else
      false
    end
  rescue
    _exception -> false
  end

  @doc """
  Receives telemetry callbacks and forwards sanitized event data to the recorder.
  """
  def handle_event(event_name, measurements, metadata, recorder) when is_pid(recorder) do
    GenServer.cast(recorder, {:telemetry_event, event_name, measurements, metadata})
  end

  defp build_event(event_name, measurements, metadata) do
    %{
      at: DateTime.utc_now() |> DateTime.to_iso8601(),
      event: event_name,
      measurements: measurements |> json_safe() |> atomize_known(),
      metadata: metadata |> sanitize_metadata() |> json_safe() |> atomize_known()
    }
  end

  defp append_event(event) do
    Vibe.Storage.ensure!()

    %TelemetryEvent{
      name: Enum.join(event.event, "."),
      at: parse_datetime!(event.at),
      measurements: json_safe(event.measurements),
      metadata: json_safe(event.metadata)
    }
    |> Vibe.Repo.insert()
  rescue
    _exception -> {:error, :telemetry_insert_failed}
  end

  defp remember(recent, event), do: [event | Enum.take(recent, @max_recent - 1)]

  defp decode_record(%TelemetryEvent{} = event) do
    %{
      at: DateTime.to_iso8601(event.at),
      event: decode_event_name(event.name),
      measurements: atomize_known(event.measurements || %{}),
      metadata: atomize_known(event.metadata || %{})
    }
  end

  defp decode_event_name(name) when is_binary(name) do
    name
    |> String.split(".", trim: true)
    |> Enum.map(&String.to_existing_atom/1)
  rescue
    _exception -> []
  end

  defp parse_datetime!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> Vibe.Storage.normalize_datetime(dt)
      _ -> Vibe.Storage.normalize_datetime(DateTime.utc_now())
    end
  end

  defp maybe_reverse_limited(events, :infinity), do: events
  defp maybe_reverse_limited(events, limit) when is_integer(limit), do: Enum.reverse(events)

  defp sanitize_metadata(metadata), do: scrub_sensitive(metadata)

  defp scrub_sensitive(%_{} = struct), do: struct |> Map.from_struct() |> scrub_sensitive()

  defp scrub_sensitive(map) when is_map(map) do
    Map.new(map, fn {key, value} -> scrub_entry(key, value) end)
  end

  defp scrub_sensitive(list) when is_list(list) do
    Enum.map(list, fn
      {key, value} when is_binary(key) or is_atom(key) -> elem(scrub_entry(key, value), 1)
      value -> scrub_sensitive(value)
    end)
  end

  defp scrub_sensitive(value) when is_binary(value), do: scrub_string(value)
  defp scrub_sensitive(value), do: value

  defp scrub_entry(key, value) do
    normalized_key = key |> to_string() |> String.downcase()

    cond do
      normalized_key in [
        "authorization",
        "cookie",
        "set-cookie",
        "api_key",
        "api-key",
        "token",
        "access_token",
        "refresh_token"
      ] ->
        {key, "[REDACTED]"}

      normalized_key in ["headers", "body", "input", "messages", "prompt", "instructions"] ->
        {key, "[REDACTED]"}

      normalized_key == "request" ->
        {key, sanitize_request(value)}

      normalized_key == "result" ->
        {key, sanitize_result(value)}

      true ->
        {key, scrub_sensitive(value)}
    end
  end

  defp sanitize_request(%_{} = request), do: request |> Map.from_struct() |> sanitize_request()

  defp sanitize_request(request) when is_map(request) do
    request
    |> Map.take([:method, :scheme, :host, :port, :path])
    |> Map.merge(Map.take(request, ["method", "scheme", "host", "port", "path"]))
  end

  defp sanitize_request(_request), do: "[REDACTED]"

  defp sanitize_result({status, response}), do: [json_safe(status), sanitize_response(response)]
  defp sanitize_result(%_{} = response), do: sanitize_response(response)
  defp sanitize_result(response) when is_map(response), do: sanitize_response(response)
  defp sanitize_result(_result), do: "[REDACTED]"

  defp sanitize_response(%_{} = response),
    do: response |> Map.from_struct() |> sanitize_response()

  defp sanitize_response(response) when is_map(response) do
    response
    |> Map.take([:status, :headers, :trailers, "status", "headers", "trailers"])
    |> scrub_sensitive()
  end

  defp sanitize_response(_response), do: "[REDACTED]"

  defp scrub_string("Bearer " <> _token), do: "Bearer [REDACTED]"

  defp scrub_string(value) do
    if String.valid?(value), do: value, else: "[BINARY #{byte_size(value)} bytes]"
  end

  defp json_safe(%_{} = struct), do: struct |> Map.from_struct() |> json_safe()

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {json_key(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> json_safe()
  defp json_safe(pid) when is_pid(pid), do: inspect(pid)
  defp json_safe(ref) when is_reference(ref), do: inspect(ref)
  defp json_safe(fun) when is_function(fun), do: inspect(fun)
  defp json_safe(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value), do: value

  defp json_safe(value), do: inspect(value, limit: 20)

  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key) when is_binary(key), do: key
  defp json_key(key), do: inspect(key)

  defp atomize_known(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {safe_key(key), atomize_known(value)} end)
  end

  defp atomize_known(list) when is_list(list), do: Enum.map(list, &atomize_known/1)
  defp atomize_known(value), do: value

  defp safe_key(key) when is_binary(key), do: Map.get(@decode_keys, key, key)

  defp safe_key(key), do: key
end
