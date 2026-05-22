defmodule Vibe.Session.Store.Summary do
  @moduledoc "Session summary extraction for dashboards and previews."
  alias Vibe.Session.Store.EventLog
  alias Vibe.Storage.Schema.Session

  @spec refresh(String.t(), (-> [{non_neg_integer(), Vibe.Event.t()}])) :: :ok
  def refresh(session_id, fallback \\ fn -> [] end) do
    case summary(session_id, fallback) do
      nil -> update_empty(session_id)
      summary -> update_summary(session_id, summary)
    end
  end

  @spec summary(String.t(), (-> [{non_neg_integer(), Vibe.Event.t()}])) :: map() | nil
  def summary(session_id, fallback \\ fn -> [] end) do
    events = EventLog.session_events(session_id, fallback)

    if events == [] do
      nil
    else
      state = summarize_events(events)
      messages = conversation_messages(state.messages)
      first_user = Enum.find(messages, &(&1[:role] == :user))
      last_message = List.last(messages)

      %{
        status: state.status,
        model: state.model,
        message_count: length(messages),
        first_message: preview_message(first_user),
        last_message_preview: preview_message(last_message),
        usage: state.usage
      }
    end
  end

  defp update_empty(session_id) do
    case Vibe.Repo.get(Session, session_id) do
      nil ->
        :ok

      session ->
        session |> Ecto.Changeset.change(%{message_count: 0}) |> Vibe.Repo.update!() |> ok()
    end
  end

  defp update_summary(session_id, summary) do
    session = Vibe.Repo.get!(Session, session_id)

    session
    |> Ecto.Changeset.change(%{
      status: to_string(summary.status || :idle),
      model: summary.model,
      message_count: summary.message_count,
      first_message_preview: summary.first_message,
      last_message_preview: summary.last_message_preview,
      usage_input_tokens: get_in(summary.usage, [:input_tokens]) || 0,
      usage_output_tokens: get_in(summary.usage, [:output_tokens]) || 0,
      usage_total_tokens: get_in(summary.usage, [:total_tokens]) || 0,
      usage_total_cost: get_in(summary.usage, [:total_cost]) || 0.0
    })
    |> Vibe.Repo.update!()
    |> ok()
  end

  defp summarize_events(events) do
    Enum.reduce(events, initial_summary(), fn {_seq, event}, state ->
      reduce_event(state, event)
    end)
    |> finalize_status()
  end

  defp initial_summary do
    %{
      status: :idle,
      model: nil,
      messages: [],
      usage: Vibe.Model.Usage.empty(),
      streaming?: false,
      running_tools: MapSet.new()
    }
  end

  defp reduce_event(state, %{type: :user_message_added, data: data}) do
    data = payload_map(data)

    state
    |> append_message(%{role: :user, text: Map.get(data, :text, "")})
    |> Map.put(:status, :working)
  end

  defp reduce_event(state, %{type: :assistant_message_added, data: data}) do
    data = payload_map(data)

    state
    |> append_message(%{role: :assistant, text: Map.get(data, :text, "")})
    |> Map.put(:status, :idle)
    |> Map.put(:streaming?, false)
  end

  defp reduce_event(state, %{type: :assistant_stream_started}) do
    %{state | status: :working, streaming?: true}
  end

  defp reduce_event(state, %{type: :assistant_stream_finished, data: data}) do
    text = data |> payload_map() |> Map.get(:text)

    state =
      if is_binary(text) and text != "",
        do: append_message(state, %{role: :assistant, text: text}),
        else: state

    %{state | status: :idle, streaming?: false}
  end

  defp reduce_event(state, %{type: :tool_started, data: data}) do
    id = data |> tool_event() |> Map.get(:id)
    running = if id, do: MapSet.put(state.running_tools, id), else: state.running_tools
    %{state | status: :working, running_tools: running}
  end

  defp reduce_event(state, %{type: :tool_finished, data: data}) do
    id = data |> tool_event() |> Map.get(:id)
    running = if id, do: MapSet.delete(state.running_tools, id), else: state.running_tools

    %{
      state
      | running_tools: running,
        status: if(MapSet.size(running) == 0, do: :idle, else: :working)
    }
  end

  defp reduce_event(state, %{type: :model_selected, data: data}) do
    %{state | model: data |> payload_map() |> Map.get(:model)}
  end

  defp reduce_event(state, %{type: :usage_updated, data: data}) do
    %{state | usage: summarize_usage([state.usage, payload_map(data)])}
  end

  defp reduce_event(state, %{type: :status_changed, data: data}) do
    %{state | status: data |> payload_map() |> Map.get(:status, state.status)}
  end

  defp reduce_event(state, _event), do: state

  defp finalize_status(%{status: :working, streaming?: false, running_tools: running} = state)
       when map_size(running) == 0,
       do: %{state | status: :idle}

  defp finalize_status(state), do: state

  defp append_message(state, message), do: %{state | messages: state.messages ++ [message]}

  defp preview_message(nil), do: ""

  defp preview_message(message) when is_map(message) do
    message
    |> Map.get(:text, "")
    |> preview_text()
  end

  defp preview_text(text) when is_binary(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, 120)
  end

  defp preview_text(value), do: value |> inspect(limit: 6, printable_limit: 180) |> preview_text()

  defp conversation_messages(messages) do
    Enum.reject(messages, fn message -> message[:role] == :system end)
  end

  defp payload_map(%struct{} = payload) when is_atom(struct),
    do: payload |> Map.from_struct() |> drop_nil()

  defp payload_map(payload) when is_map(payload), do: payload
  defp payload_map(_payload), do: %{}

  defp tool_event(%{event: event}), do: event |> payload_map()
  defp tool_event(%{data: %{event: event}}), do: event |> payload_map()
  defp tool_event(data), do: data |> payload_map()

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp summarize_usage(usages) do
    Enum.reduce(
      usages,
      Vibe.Model.Usage.empty(),
      fn usage, acc ->
        usage = payload_map(usage)

        acc
        |> add_int(:input_tokens, usage)
        |> add_int(:output_tokens, usage)
        |> add_total_tokens(usage)
        |> add_float(:total_cost, usage)
      end
    )
  end

  defp add_int(acc, key, usage), do: Map.update!(acc, key, &(&1 + int(usage[key])))

  defp add_total_tokens(acc, usage) do
    total = int(usage[:total_tokens])

    if total > 0,
      do: Map.update!(acc, :total_tokens, &(&1 + total)),
      else:
        Map.update!(
          acc,
          :total_tokens,
          &(&1 + int(usage[:input_tokens]) + int(usage[:output_tokens]))
        )
  end

  defp add_float(acc, key, usage), do: Map.update!(acc, key, &(&1 + float(usage[key])))

  defp int(value) when is_integer(value), do: value
  defp int(_value), do: 0

  defp float(value) when is_integer(value), do: value * 1.0
  defp float(value) when is_float(value), do: value
  defp float(_value), do: 0.0

  defp ok(_result), do: :ok
end
