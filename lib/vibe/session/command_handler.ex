defmodule Vibe.Session.CommandHandler do
  @moduledoc "Interprets session command intents into semantic session events."

  alias Vibe.Event
  alias Vibe.Model.{Effort, Switcher}
  alias Vibe.Session.Command, as: SlashCommands
  alias Vibe.Session.Command.Intent, as: Command
  alias Vibe.Session.PromptLifecycle
  alias Vibe.UI.Selector

  @type session_state :: map()
  @type context :: %{emit: function(), emit_opts: function()}

  @spec handle(Command.t(), session_state(), pid(), context()) :: session_state()
  def handle(%Command{} = command, state, caller, context) when is_map(context) do
    if locked?(state, caller) and command.type == :submit_prompt do
      locked_notice(state, context)
    else
      handle(command, state, context)
    end
  end

  @spec metadata(Command.t(), session_state()) :: map()
  def metadata(%Command{} = command, state) do
    %{
      session_id: state.state.session_id,
      command: command.type,
      status: state.state.status
    }
  end

  @spec normalize(Command.t() | atom() | {atom(), map()}) :: Command.t()
  def normalize(%Command{} = command), do: command
  def normalize(type) when is_atom(type), do: Command.new(type)
  def normalize({type, data}) when is_atom(type) and is_map(data), do: Command.new(type, data)

  defp handle(%Command{type: :submit_prompt, data: %{content: content}}, state, context)
       when is_list(content) do
    PromptLifecycle.submit(state, content, context.emit)
  end

  defp handle(%Command{type: :submit_prompt, data: %{text: text}}, state, context)
       when is_binary(text) do
    PromptLifecycle.submit(state, text, context.emit)
  end

  defp handle(%Command{type: :cancel_stream}, state, context) do
    PromptLifecycle.cancel(state, context.emit)
  end

  defp handle(%Command{type: :set_goal, data: %{objective: objective} = data}, state, context)
       when is_binary(objective) do
    case Vibe.Goals.set(state.state.session_id, objective,
           token_budget: Map.get(data, :token_budget)
         ) do
      {:ok, goal} ->
        emit(
          state,
          Event.new(:goal_set, state.state.session_id, Vibe.Event.Goal.set(goal)),
          context
        )

      {:error, reason} ->
        notify(state, goal_error(reason), context)
    end
  end

  defp handle(%Command{type: :update_goal_status, data: %{status: status}}, state, context) do
    case Vibe.Goals.update_status(state.state.session_id, status) do
      {:ok, goal} ->
        emit(
          state,
          Event.new(:goal_updated, state.state.session_id, Vibe.Event.Goal.updated(goal)),
          context
        )

      {:error, reason} ->
        notify(state, goal_error(reason), context)
    end
  end

  defp handle(%Command{type: :clear_goal}, state, context) do
    case Vibe.Goals.clear(state.state.session_id) do
      :ok ->
        emit(
          state,
          Event.new(:goal_cleared, state.state.session_id, Vibe.Event.Goal.cleared()),
          context
        )

      {:error, reason} ->
        notify(state, goal_error(reason), context)
    end
  end

  defp handle(%Command{type: :background_session}, state, context) do
    emit(
      state,
      Event.new(:session_backgrounded, state.state.session_id, Vibe.Event.Session.backgrounded()),
      context,
      persist?: false
    )
  end

  defp handle(%Command{type: :branch_session, data: %{seq: seq}}, state, context) do
    branch_id = Vibe.Session.Store.new_id()

    case Vibe.Session.Store.branch(state.state.session_id, seq, branch_id) do
      :ok ->
        emit(
          state,
          Event.new(
            :session_selected,
            state.state.session_id,
            Vibe.Event.Session.selected(branch_id)
          ),
          context
        )

      {:error, reason} ->
        notify(state, "Branch failed: #{inspect(reason)}", context)
    end
  end

  defp handle(%Command{type: :toggle_truncation}, state, context) do
    emit(
      state,
      Event.new(
        :truncation_toggled,
        state.state.session_id,
        Vibe.Event.Surface.truncation_toggled()
      ),
      context
    )
  end

  defp handle(%Command{type: :open_model_selector}, state, context),
    do: open_model_selector(state, context)

  defp handle(%Command{type: :open_effort_selector}, state, context),
    do: open_effort_selector(state, context)

  defp handle(%Command{type: :cycle_model, data: data}, state, context) do
    direction = Map.get(data, :direction, :forward)

    case Switcher.cycle_model(state.state.model, direction) do
      {:ok, model} ->
        emit(
          state,
          Event.new(:model_selected, state.state.session_id, Vibe.Event.Model.selected(model)),
          context
        )

      {:error, :one_model} ->
        notify(state, "Only one model available", context)
    end
  end

  defp handle(%Command{type: :select_model, data: %{model: model}}, state, context)
       when is_binary(model) do
    emit(
      state,
      Event.new(:model_selected, state.state.session_id, Vibe.Event.Model.selected(model)),
      context
    )
  end

  defp handle(%Command{type: :cycle_effort}, state, context) do
    effort = Switcher.cycle_effort(state.state.effort, state.state.model)

    emit(
      state,
      Event.new(
        :effort_selected,
        state.state.session_id,
        Vibe.Event.Model.effort_selected(effort)
      ),
      context
    )
  end

  defp handle(%Command{type: :select_effort, data: %{effort: effort}}, state, context)
       when effort in [:off, :minimal, :low, :medium, :high, :xhigh] do
    emit(
      state,
      Event.new(
        :effort_selected,
        state.state.session_id,
        Vibe.Event.Model.effort_selected(effort)
      ),
      context
    )
  end

  defp handle(
         %Command{type: :slash_command_submitted, data: %{command: command} = data},
         state,
         context
       ) do
    state =
      emit(
        state,
        Event.new(
          :slash_command_submitted,
          state.state.session_id,
          Vibe.Event.Command.slash_submitted(data)
        ),
        context
      )

    run_slash_command(command, Map.get(data, :args, ""), state, context)
  end

  defp handle(%Command{type: :selector_confirmed, data: data}, state, context) do
    state =
      emit(
        state,
        Event.new(
          :selector_confirmed,
          state.state.session_id,
          Vibe.Event.Selector.confirmed(data)
        ),
        context
      )

    run_selector_action(data, state, context)
  end

  defp handle(%Command{type: :open_overlay, data: data}, state, context) do
    emit(
      state,
      Event.new(:overlay_opened, state.state.session_id, Vibe.Event.Surface.overlay_opened(data)),
      context
    )
  end

  defp handle(%Command{type: :close_overlay}, state, context) do
    emit(
      state,
      Event.new(:overlay_closed, state.state.session_id, Vibe.Event.Surface.overlay_closed()),
      context
    )
  end

  defp handle(%Command{type: type, data: data}, state, context) do
    emit(state, Event.new(type, state.state.session_id, command_event_data(type, data)), context)
  end

  defp command_event_data(:tool_toggled, %{id: id}), do: Vibe.Event.Surface.tool_toggled(id)

  defp command_event_data(:patch_confirmation_requested, data),
    do: Vibe.Event.Command.patch_confirmation_requested(data)

  defp command_event_data(_type, data), do: data

  defp locked?(%{locked_by_job: nil}, _caller), do: false
  defp locked?(%{lock_owner: owner}, caller), do: owner != caller

  defp locked_notice(state, context) do
    emit(
      state,
      Event.new(
        :notification_added,
        state.state.session_id,
        Vibe.Event.Notification.added(
          level: :warning,
          text: "This subagent session is read-only until the job finishes."
        )
      ),
      context
    )
  end

  defp run_slash_command(command, args, state, context) do
    case SlashCommands.handle(command, args, state.state) do
      {:events, events} -> Enum.reduce(events, state, &emit(&2, &1, context))
      {:command, command} -> handle(normalize(command), state, context)
      :compact -> run_compaction(state, context)
      :ignore -> state
    end
  end

  defp run_selector_action(%{selector: :model_selector, item: model}, state, context)
       when is_binary(model) do
    handle(Command.new(:select_model, %{model: model}), state, context)
  end

  defp run_selector_action(%{selector: :effort_selector, item: effort}, state, context)
       when is_binary(effort) do
    case Effort.from_string(effort) do
      {:ok, effort} -> handle(Command.new(:select_effort, %{effort: effort}), state, context)
      {:error, {:unknown_effort, value}} -> notify(state, "unknown effort: #{value}", context)
    end
  end

  defp run_selector_action(data, state, context) do
    case SlashCommands.selector_action(data, state.state) do
      {:events, events} ->
        Enum.reduce(events, state, &emit(&2, &1, context))

      {:command, command} when is_binary(command) ->
        run_slash_command(command, "", state, context)

      {:command, command} ->
        handle(normalize(command), state, context)

      :ignore ->
        state
    end
  end

  defp open_model_selector(state, context) do
    items = Switcher.model_options(state.state.model)

    selector = %Selector{
      kind: :model_selector,
      title: "Model",
      items: items,
      selected: selected_index(items, state.state.model),
      limit: 8
    }

    emit(
      state,
      Event.new(:selector_opened, state.state.session_id, Vibe.Event.Selector.opened(selector)),
      context
    )
  end

  defp open_effort_selector(state, context) do
    items = Enum.map(Switcher.effort_options(state.state.model), &Effort.label/1)
    current = Effort.label(state.state.effort || Effort.default())

    selector = %Selector{
      kind: :effort_selector,
      title: "Effort",
      items: items,
      selected: selected_index(items, current),
      limit: 6
    }

    emit(
      state,
      Event.new(:selector_opened, state.state.session_id, Vibe.Event.Selector.opened(selector)),
      context
    )
  end

  defp selected_index(items, current) do
    case Enum.find_index(items, &(&1 == current)) do
      nil -> 0
      index -> index
    end
  end

  defp notify(state, text, context) do
    emit(
      state,
      Event.new(
        :notification_added,
        state.state.session_id,
        Vibe.Event.Notification.added(level: :info, text: text)
      ),
      context
    )
  end

  defp goal_error(:empty_objective), do: "Goal objective must not be empty"

  defp goal_error({:objective_too_long, actual, max}) do
    "Goal objective is too long: #{actual} characters. Limit: #{max} characters. Put longer instructions in a file and refer to that file in the goal."
  end

  defp goal_error(:not_found), do: "No goal is currently set"
  defp goal_error(reason), do: "Goal error: #{inspect(reason)}"

  defp run_compaction(state, context) do
    session_id = state.state.session_id
    tokens_before = estimate_tokens(state.state.messages)

    state =
      emit(
        state,
        Event.new(
          :context_compaction_started,
          session_id,
          Vibe.Event.ContextCompaction.started(tokens_before)
        ),
        context
      )

    case Vibe.Context.compact(session_id: session_id) do
      {:ok, %{summary: summary}} ->
        emit(
          state,
          Event.new(
            :context_compaction_finished,
            session_id,
            Vibe.Event.ContextCompaction.finished(summary)
          ),
          context
        )

      {:error, reason} ->
        emit(
          state,
          Event.new(
            :context_compaction_failed,
            session_id,
            Vibe.Event.ContextCompaction.failed(inspect(reason))
          ),
          context
        )
    end
  end

  defp estimate_tokens(messages) do
    messages
    |> Enum.map_join("\n", fn message ->
      message
      |> Map.take([:text, :result, :error])
      |> Enum.find_value(fn {_key, value} -> value end)
      |> token_text()
    end)
    |> String.length()
    |> div(4)
  end

  defp token_text(nil), do: ""
  defp token_text(value) when is_binary(value), do: value
  defp token_text(value), do: inspect(value, limit: 20)

  defp emit(state, event, context), do: context.emit.(state, event)
  defp emit(state, event, context, opts), do: context.emit_opts.(state, event, opts)
end
