defmodule Exy.Session.PromptLifecycle do
  @moduledoc false

  alias Exy.Model.Usage
  alias Exy.UI.{Event, PromptRunner}

  @type emit_fun :: (map(), Event.t() -> map())

  @spec llm_opts(keyword()) :: keyword()
  def llm_opts(opts) do
    opts
    |> Keyword.take([:model, :role, :system, :allowed_tools])
    |> maybe_put_llm_provider_options(Keyword.get(opts, :provider_options))
  end

  @spec submit(map(), String.t(), emit_fun()) :: map()
  def submit(state, text, emit) when is_binary(text) do
    session_id = state.state.session_id
    state = emit.(state, Event.new(:prompt_submitted, session_id, %{text: text}))
    state = emit.(state, Event.new(:user_message_added, session_id, %{text: text}))
    ask_fun = state.ask_fun
    parent = self()
    ref = make_ref()
    context = %{session_id: session_id}
    Exy.Memory.Manager.on_turn_start(length(state.state.messages), text, context)
    prompt_text = prompt_with_memory(text, context)

    {ask_opts, state} = ask_options(state, parent, ref, session_id, emit)

    {:ok, task} = PromptRunner.start(ask_fun, prompt_text, ask_opts, parent, ref)

    %{state | prompt_task: task, prompt_ref: ref, active_agent: nil, last_user_prompt: text}
  end

  @spec cancel(map(), emit_fun()) :: map()
  def cancel(%{prompt_task: nil} = state, _emit), do: state

  def cancel(state, emit) do
    PromptRunner.cancel(state.active_agent, state.prompt_task)

    state
    |> Map.merge(%{prompt_task: nil, prompt_ref: nil, active_agent: nil})
    |> emit.(Event.new(:assistant_aborted, state.state.session_id, %{reason: "cancelled"}))
  end

  @spec record_result(map(), {:ok, term()} | {:error, term()}, emit_fun()) :: map()
  def record_result(state, {:ok, response}, emit) do
    Exy.Memory.Manager.sync_turn(state.last_user_prompt || "", response_text(response), %{
      session_id: state.state.session_id
    })

    state = %{state | last_user_prompt: nil}
    state = record_successful_response(state, response, emit)

    case Usage.from_response(response) do
      nil -> state
      usage -> emit.(state, Event.new(:usage_updated, state.state.session_id, usage))
    end
  end

  def record_result(state, {:error, reason}, emit) do
    reason = inspect(reason)
    state = %{state | last_user_prompt: nil}

    state =
      emit.(
        state,
        Event.new(:assistant_aborted, state.state.session_id, %{reason: reason})
      )

    emit.(
      state,
      Event.new(:assistant_message_added, state.state.session_id, %{error: reason})
    )
  end

  defp ask_options(%{streaming?: true} = state, parent, ref, session_id, emit) do
    state = emit.(state, Event.new(:assistant_stream_started, session_id, %{}))

    ask_opts =
      state.llm_opts
      |> base_ask_opts(parent, ref, session_id)
      |> Keyword.put(:on_result, &send(parent, {:assistant_delta, &1}))
      |> Keyword.put(:on_thinking, &send(parent, {:assistant_thinking_delta, &1}))

    {ask_opts, state}
  end

  defp ask_options(state, parent, ref, session_id, _emit) do
    {base_ask_opts(state.llm_opts, parent, ref, session_id), state}
  end

  defp base_ask_opts(opts, parent, ref, session_id) do
    opts
    |> Keyword.put(:session_id, session_id)
    |> Keyword.put(:tool_context, %{session_id: session_id})
    |> Keyword.put(:stream_owner, {parent, ref})
    |> Keyword.put(:on_tool_started, &send(parent, {:tool_started, &1}))
    |> Keyword.put(:on_tool_finished, &send(parent, {:tool_finished, &1}))
  end

  defp maybe_put_llm_provider_options(opts, []), do: opts
  defp maybe_put_llm_provider_options(opts, nil), do: opts

  defp maybe_put_llm_provider_options(opts, provider_options),
    do: Keyword.put(opts, :llm_opts, provider_options: provider_options)

  defp prompt_with_memory(text, context) do
    case Exy.Memory.Manager.prefetch(text, context) do
      "" -> text
      memory -> text <> "\n\n" <> memory
    end
  end

  defp record_successful_response(
         %{state: %{streaming_message: %{text: text}}} = state,
         _response,
         emit
       )
       when is_binary(text) and text != "" do
    emit.(state, Event.new(:assistant_stream_finished, state.state.session_id, %{}))
  end

  defp record_successful_response(state, response, emit) do
    emit.(state, Event.new(:assistant_message_added, state.state.session_id, %{result: response}))
  end

  defp response_text(response) when is_binary(response), do: response
  defp response_text(%{output: output}) when is_binary(output), do: output
  defp response_text(response), do: inspect(response)
end
