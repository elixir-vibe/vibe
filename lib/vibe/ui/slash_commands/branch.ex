defmodule Vibe.UI.SlashCommands.Branch do
  @moduledoc "Slash command: /branch — branch the session from an earlier point."
  @behaviour Vibe.UI.SlashCommands.Command

  @impl true
  def spec, do: %{name: "branch", description: "Branch from earlier message"}

  @impl true
  def run(args, ui_state) do
    case parse_target(args, ui_state) do
      {:ok, seq} ->
        {:command, {:branch_session, %{seq: seq}}}

      {:error, reason} ->
        {:events, [notification(:error, reason)]}
    end
  end

  defp parse_target("", ui_state) do
    count = length(ui_state.messages)

    if count > 1 do
      {:ok, count - 1}
    else
      {:error, "Nothing to branch from"}
    end
  end

  defp parse_target(args, _ui_state) do
    case Integer.parse(String.trim(args)) do
      {n, _rest} when n > 0 -> {:ok, n}
      _error -> {:error, "Usage: /branch [message-number]"}
    end
  end

  defp notification(level, text) do
    Vibe.UI.Event.new(:notification_added, "", %{level: level, text: text})
  end
end
