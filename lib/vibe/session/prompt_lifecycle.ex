defmodule Vibe.Session.PromptLifecycle do
  @moduledoc "Prompt submission, cancellation, memory injection, and result recording."
  alias Vibe.Model.{Content, Error, Usage}
  alias Vibe.Event
  alias Vibe.UI.PromptRunner

  require Vibe.Debug

  @type emit_fun :: (map(), Event.t() -> map())

  @spec llm_opts(keyword()) :: keyword()
  def llm_opts(opts) do
    opts
    |> Keyword.take([:model, :role, :system, :allowed_tools, :effort])
    |> maybe_put_llm_provider_options(Keyword.get(opts, :provider_options))
  end

  @spec submit(map(), String.t() | [Content.t()], emit_fun()) :: map()
  def submit(state, prompt, emit) when is_binary(prompt) or is_list(prompt) do
    text = Content.summarize(prompt)
    session_id = state.state.session_id
    event_data = prompt_event_data(prompt, text)

    state =
      emit.(
        state,
        Event.new(:prompt_submitted, session_id, Vibe.Event.Command.prompt_submitted(event_data))
      )

    state =
      emit.(
        state,
        Event.new(:user_message_added, session_id, Vibe.Event.Message.user_added(event_data))
      )

    ask_fun = state.ask_fun
    parent = self()
    ref = make_ref()
    context = %{session_id: session_id, cwd: state.state.cwd}
    Vibe.Memory.Manager.on_turn_start(length(state.state.messages), text, context)
    prompt_text = prompt_with_memory(text, context)
    dispatch_context_plugins(state.state.messages, context)

    {ask_opts, state} = ask_options(state, parent, ref, session_id, emit)
    ask_opts = maybe_put_semantic_content(ask_opts, prompt)

    {:ok, task} = PromptRunner.start(ask_fun, prompt_text, ask_opts, parent, ref)

    %{state | prompt_task: task, prompt_ref: ref, active_agent: nil, last_user_prompt: text}
  end

  @spec cancel(map(), emit_fun()) :: map()
  def cancel(%{prompt_task: nil} = state, _emit), do: state

  def cancel(state, emit) do
    PromptRunner.cancel(state.active_agent, state.prompt_task)
    Vibe.Eval.cancel(state.state.session_id)

    state
    |> Map.merge(%{prompt_task: nil, prompt_ref: nil, active_agent: nil})
    |> emit.(
      Event.new(
        :assistant_aborted,
        state.state.session_id,
        Vibe.Event.AssistantStream.aborted(reason: "Cancelled.")
      )
    )
  end

  @spec record_result(map(), {:ok, term()} | {:error, term()}, emit_fun()) :: map()
  def record_result(state, {:ok, response}, emit) do
    Vibe.Memory.Manager.sync_turn(state.last_user_prompt || "", response_text(response), %{
      session_id: state.state.session_id
    })

    state = %{state | last_user_prompt: nil}
    state = record_successful_response(state, response, emit)

    case Usage.from_response(response) do
      nil -> state
      usage -> record_usage(state, usage, emit)
    end
  end

  def record_result(state, {:error, reason}, emit) do
    error = Error.normalize(reason)
    state = %{state | last_user_prompt: nil}

    state =
      emit.(
        state,
        Event.new(
          :assistant_aborted,
          state.state.session_id,
          Vibe.Event.AssistantStream.aborted(reason: error.message, error: error, notify?: false)
        )
      )

    emit.(
      state,
      Event.new(
        :assistant_message_added,
        state.state.session_id,
        Vibe.Event.Message.assistant_added(error: error)
      )
    )
  end

  defp ask_options(%{streaming?: true} = state, parent, ref, session_id, emit) do
    state =
      emit.(
        state,
        Event.new(:assistant_stream_started, session_id, Vibe.Event.AssistantStream.started())
      )

    ask_opts =
      state
      |> current_llm_opts()
      |> base_ask_opts(parent, ref, session_id)
      |> Keyword.put(:on_result, &send(parent, {:assistant_delta, &1}))
      |> Keyword.put(:on_thinking, &send(parent, {:assistant_thinking_delta, &1}))
      |> Keyword.put(:on_tool_preparing, &send(parent, {:tool_preparing, &1}))

    {ask_opts, state}
  end

  defp ask_options(state, parent, ref, session_id, _emit) do
    {base_ask_opts(current_llm_opts(state), parent, ref, session_id), state}
  end

  defp current_llm_opts(state) do
    opts =
      state.llm_opts
      |> Keyword.put(:model, state.state.model)
      |> Keyword.put(:effort, state.state.effort)

    case Vibe.Agent.Options.resolve(opts) do
      {:ok, resolved} ->
        maybe_put_llm_provider_options(resolved, Keyword.get(resolved, :provider_options))

      {:error, _reason} ->
        opts
    end
  end

  defp base_ask_opts(opts, parent, ref, session_id) do
    opts
    |> Keyword.put(:session_id, session_id)
    |> Keyword.put(:tool_context, %{session_id: session_id})
    |> Keyword.put(:stream_owner, {parent, ref})
    |> Keyword.put(:on_tool_preparing, &send(parent, {:tool_preparing, &1}))
    |> Keyword.put(:on_tool_started, &send(parent, {:tool_started, &1}))
    |> Keyword.put(:on_tool_finished, &send(parent, {:tool_finished, &1}))
  end

  defp maybe_put_llm_provider_options(opts, []), do: opts
  defp maybe_put_llm_provider_options(opts, nil), do: opts

  defp maybe_put_llm_provider_options(opts, provider_options),
    do: Keyword.put(opts, :llm_opts, provider_options: provider_options)

  defp maybe_put_semantic_content(opts, prompt) when is_list(prompt) do
    Keyword.update(opts, :tool_context, %{semantic_prompt_content: prompt}, fn context ->
      Map.put(context, :semantic_prompt_content, prompt)
    end)
  end

  defp maybe_put_semantic_content(opts, _prompt), do: opts

  defp prompt_event_data(prompt, text) when is_list(prompt) do
    images = Enum.filter(prompt, &match?(%Content.Image{}, &1))

    %{text: text, content: prompt, image_count: length(images)}
  end

  defp prompt_event_data(_prompt, text), do: %{text: text}

  defp prompt_with_memory(text, context) do
    [
      text,
      Vibe.Goals.context_block(Map.get(context, :session_id)),
      Vibe.Memory.Manager.prefetch(text, context),
      active_skill_context(text),
      recalled_history(text, context)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp active_skill_context("<skill " <> _text), do: ""
  defp active_skill_context(text), do: Vibe.Skill.context(text, limit: 3)

  defp recalled_history(text, context) do
    Vibe.Context.recall(text,
      cwd: Map.get(context, :cwd),
      exclude_session_id: Map.get(context, :session_id),
      limit: 3
    )
  end

  defp record_successful_response(%{state: %{streaming_message: %{}}} = state, response, emit) do
    text = response_text(response)

    Vibe.Debug.run do
      Vibe.Agent.Streaming.Trace.record(:surface_stream_finished, %{
        session_id: state.state.session_id,
        text: text
      })
    end

    emit.(
      state,
      Event.new(
        :assistant_stream_finished,
        state.state.session_id,
        Vibe.Event.AssistantStream.finished(text)
      )
    )
  end

  defp record_successful_response(state, response, emit) do
    emit.(
      state,
      Event.new(
        :assistant_message_added,
        state.state.session_id,
        Vibe.Event.Message.assistant_added(result: response)
      )
    )
  end

  defp record_usage(state, usage, emit) do
    state =
      case Vibe.Goals.add_usage(state.state.session_id, usage) do
        {:ok, goal} ->
          emit.(
            state,
            Event.new(:goal_updated, state.state.session_id, Vibe.Event.Goal.updated(goal))
          )

        _result ->
          state
      end

    emit.(
      state,
      Event.new(:usage_updated, state.state.session_id, Vibe.Event.Model.usage_updated(usage))
    )
  end

  defp response_text(response) when is_binary(response), do: response
  defp response_text(%{output: output}) when is_binary(output), do: output
  defp response_text(response), do: inspect(response)

  defp dispatch_context_plugins(messages, context) do
    if Process.whereis(Vibe.Plugin.Manager) do
      Task.start(fn -> GenServer.call(Vibe.Plugin.Manager, {:context, messages, context}) end)
    end

    :ok
  rescue
    _error -> :ok
  end
end
