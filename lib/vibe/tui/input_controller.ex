defmodule Vibe.TUI.InputController do
  @moduledoc "Routes semantic TUI input actions into editor and session commands."

  alias Vibe.Session
  alias Vibe.UI.{Autocomplete, Command, EditorServer, FileAutocomplete, Reducer, SlashCommands}

  @type app_state :: map()

  @spec handle_key(Vibe.UI.Editor.key(), app_state()) :: app_state()
  def handle_key(key, state) do
    cond do
      app_action_key?(key) ->
        handle_app_action_key(key, state)

      key == :left and empty_prompt?(state) ->
        handle_app_action_key(:background_session, state)

      selector_open?(state) ->
        handle_selector_key(key, state)

      autocomplete_key?(key, state) ->
        handle_autocomplete_key(key, state)

      true ->
        commands = EditorServer.key(state.editor, key)
        Enum.each(commands, &handle_editor_command(&1, state))
        refresh_autocomplete(state)
    end
  end

  defp app_action_key?(key),
    do:
      key in [
        :cycle_model_forward,
        :cycle_model_backward,
        :open_model_selector,
        :cycle_effort,
        :background_session
      ]

  defp handle_app_action_key(:cycle_model_forward, state) do
    dispatch_async(state.ui, Command.new(:cycle_model, %{direction: :forward}))
    state
  end

  defp handle_app_action_key(:cycle_model_backward, state) do
    dispatch_async(state.ui, Command.new(:cycle_model, %{direction: :backward}))
    state
  end

  defp handle_app_action_key(:open_model_selector, state) do
    dispatch_async(state.ui, Command.new(:open_model_selector))
    state
  end

  defp handle_app_action_key(:cycle_effort, state) do
    dispatch_async(state.ui, Command.new(:cycle_effort))
    state
  end

  defp handle_app_action_key(:background_session, state) do
    dispatch_async(state.ui, Command.new(:background_session))
    state
  end

  defp empty_prompt?(state) do
    state.editor |> EditorServer.state() |> Map.get(:text, "") |> String.trim() == ""
  end

  defp selector_open?(state), do: not is_nil(state.ui_snapshot.selector)

  defp handle_selector_key(:up, state) do
    Session.dispatch(state.ui, Command.new(:selector_moved, %{direction: -1}))
    state
  end

  defp handle_selector_key(:down, state) do
    Session.dispatch(state.ui, Command.new(:selector_moved, %{direction: 1}))
    state
  end

  defp handle_selector_key(:submit, state) do
    selector = state.ui_snapshot.selector
    item = selector |> Map.get(:items, []) |> Enum.at(Map.get(selector, :selected, 0))
    data = %{selector: Map.get(selector, :kind), item: item}

    dispatch_async(state.ui, Command.new(:selector_confirmed, data))

    apply_local_event(
      state,
      Vibe.Event.new(:selector_confirmed, state.ui_snapshot.session_id, data)
    )
  end

  defp handle_selector_key(:cancel, state) do
    dispatch_async(state.ui, Command.new(:selector_closed))

    apply_local_event(
      state,
      Vibe.Event.new(:selector_closed, state.ui_snapshot.session_id, %{})
    )
  end

  defp handle_selector_key(_key, state), do: state

  defp autocomplete_key?(:submit, %{autocomplete: %Autocomplete{}} = state) do
    state.editor
    |> EditorServer.state()
    |> Map.get(:text, "")
    |> command_prefix_only?()
  end

  defp autocomplete_key?(key, %{autocomplete: %Autocomplete{}}),
    do: key in [:up, :down, :tab, :cancel]

  defp autocomplete_key?(_key, _state), do: false

  defp command_prefix_only?("/" <> text) do
    not String.match?(String.trim_leading(text), ~r/\s/)
  end

  defp command_prefix_only?(_text), do: false

  defp handle_autocomplete_key(:up, state) do
    %{state | autocomplete: Autocomplete.move(state.autocomplete, -1)}
  end

  defp handle_autocomplete_key(:down, state) do
    %{state | autocomplete: Autocomplete.move(state.autocomplete, 1)}
  end

  defp handle_autocomplete_key(:cancel, state), do: %{state | autocomplete: nil}

  defp handle_autocomplete_key(:tab, state) do
    case Autocomplete.selected_item(state.autocomplete) do
      %{value: value} -> apply_completion(state, value <> " ")
      nil -> %{state | autocomplete: nil}
    end
  end

  defp handle_autocomplete_key(:submit, state) do
    case Autocomplete.selected_item(state.autocomplete) do
      %{value: "/" <> command} ->
        :ok = EditorServer.replace(state.editor, "")

        dispatch_async(
          state.ui,
          Command.new(:slash_command_submitted, %{command: command, args: ""})
        )

        %{state | autocomplete: nil}

      %{value: value} ->
        apply_completion(state, value)

      nil ->
        %{state | autocomplete: nil}
    end
  end

  defp apply_completion(state, value) do
    case state.autocomplete.replace_from do
      pos when is_integer(pos) ->
        editor = EditorServer.state(state.editor)
        new_text = String.slice(editor.text, 0, pos) <> value
        :ok = EditorServer.replace(state.editor, new_text)
        %{state | autocomplete: nil}

      nil ->
        :ok = EditorServer.replace(state.editor, value)
        %{state | autocomplete: nil}
    end
  end

  defp refresh_autocomplete(state) do
    editor = EditorServer.state(state.editor)

    autocomplete =
      SlashCommands.autocomplete(editor.text) || FileAutocomplete.autocomplete(editor.text)

    %{state | autocomplete: autocomplete}
  end

  defp apply_local_event(state, event) do
    %{state | ui_snapshot: Reducer.apply_event(state.ui_snapshot, event)}
  end

  defp handle_editor_command({:submit, text}, state) do
    dispatch_async(state.ui, submit_prompt_command(text, state))
  end

  defp handle_editor_command({:slash_command, command, args}, state) do
    dispatch_async(
      state.ui,
      Command.new(:slash_command_submitted, %{command: command, args: args})
    )
  end

  defp handle_editor_command(:cancel, state) do
    dispatch_async(state.ui, Command.new(:cancel_stream))
  end

  defp handle_editor_command(:toggle_truncation, state) do
    dispatch_async(state.ui, Command.new(:toggle_truncation))
  end

  defp handle_editor_command(:paste_image, state) do
    session_id = state.ui_snapshot.session_id

    case Vibe.Prompt.ClipboardImage.save(session_id: session_id) do
      {:ok, path} ->
        marker = " @#{Path.relative_to(path, state.ui_snapshot.cwd || File.cwd!())}"
        :ok = EditorServer.insert(state.editor, marker)
        refresh_autocomplete(state)

      {:error, reason} ->
        notify_clipboard_image_error(state, reason)
    end
  end

  defp handle_editor_command({:external_editor, text}, state) do
    dispatch_async(state.ui, Command.new(:external_editor_requested, %{text: text}))
  end

  defp notify_clipboard_image_error(state, :pngpaste_not_found) do
    dispatch_async(
      state.ui,
      Command.new(:notification_added, %{
        level: :warning,
        text: "pngpaste is required to paste clipboard images"
      })
    )
  end

  defp notify_clipboard_image_error(state, reason) do
    dispatch_async(
      state.ui,
      Command.new(:notification_added, %{
        level: :warning,
        text: "could not paste clipboard image: #{inspect(reason)}"
      })
    )
  end

  defp submit_prompt_command(text, state) do
    case Vibe.Prompt.Attachments.expand(text, root: state.ui_snapshot.cwd || File.cwd!()) do
      expanded when is_list(expanded) ->
        Command.new(:submit_prompt, %{text: text, content: expanded})

      _text ->
        Command.new(:submit_prompt, %{text: text})
    end
  end

  defp dispatch_async(session, command) do
    _task =
      Task.start(fn ->
        try do
          Session.dispatch(session, command)
        catch
          :exit, _reason -> :ok
        end
      end)

    :ok
  end
end
