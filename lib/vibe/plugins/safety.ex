defmodule Vibe.Plugins.Safety do
  @moduledoc """
  Plugin: block destructive commands until the user confirms.

  Opens a confirmation selector when a command matches known dangerous
  patterns (PR creation, force push, database drops, etc.). The command
  is blocked until the user explicitly approves.
  """
  use Vibe.Plugin

  alias Vibe.Session
  alias Vibe.Event
  alias Vibe.UI.Selector

  @confirmation_timeout_ms 300_000
  @table :vibe_safety_waiters

  @impl true
  def init(_opts) do
    Vibe.Plugin.Waiters.ensure_table!(@table)
    {:ok, %{}}
  end

  @impl true
  def before_command(command, %{session_id: session_id}, state)
      when is_binary(session_id) do
    case Vibe.Plugins.Safety.Patterns.check_command(command) do
      {:ok, label} -> confirm_or_block(session_id, label, command, state)
      :safe -> {:ok, state}
    end
  end

  def before_command(_command, _context, state), do: {:ok, state}

  @impl true
  def handle_event(
        %{type: :selector_confirmed, data: %{selector: :safety_confirmation, item: answer}},
        %{session_id: session_id},
        state
      ) do
    case Vibe.Plugin.Waiters.pop(@table, session_id) do
      {:ok, pid} -> send(pid, {:safety_confirmed, answer == "Yes, proceed"})
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(
        %{type: :selector_closed},
        %{session_id: session_id},
        state
      ) do
    case Vibe.Plugin.Waiters.pop(@table, session_id) do
      {:ok, pid} -> send(pid, {:safety_confirmed, false})
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(_event, _context, state), do: {:ok, state}

  defp confirm_or_block(session_id, label, command, state) do
    case Session.lookup(session_id) do
      {:ok, session} ->
        register_waiter(session_id, self())
        open_confirmation(session, session_id, label, command)
        await_confirmation(session_id, label, state)

      _error ->
        {:ok, state}
    end
  end

  defp open_confirmation(session, session_id, label, command) do
    preview = String.slice(command, 0, 80)

    selector = %Selector{
      kind: :safety_confirmation,
      title: "#{label}?",
      items: ["Yes, proceed", "No, cancel"],
      selected: 1,
      limit: 2
    }

    Session.emit_transient_event(session, Event.new(:selector_opened, session_id, selector))

    Session.emit_transient_event(
      session,
      Event.new(
        :notification_added,
        session_id,
        Vibe.Event.Notification.added(level: :warning, text: "#{label}: #{preview}")
      )
    )
  end

  defp await_confirmation(session_id, label, state) do
    receive do
      {:safety_confirmed, true} -> {:ok, state}
      {:safety_confirmed, false} -> {:block, "#{label} cancelled by user", state}
    after
      @confirmation_timeout_ms ->
        unregister_waiter(session_id)
        {:block, "#{label} confirmation timed out", state}
    end
  end

  defp register_waiter(session_id, pid), do: Vibe.Plugin.Waiters.register(@table, session_id, pid)

  defp unregister_waiter(session_id), do: Vibe.Plugin.Waiters.unregister(@table, session_id)
end
