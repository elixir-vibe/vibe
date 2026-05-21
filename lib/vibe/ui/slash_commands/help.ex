defmodule Vibe.UI.SlashCommands.Help do
  @moduledoc "Slash command: /help — show built-in help topics."
  @behaviour Vibe.UI.SlashCommands.Command

  @impl true
  def spec do
    %{
      name: "help",
      aliases: ["h", "docs"],
      description: "Open built-in docs",
      selectors: []
    }
  end

  @impl true
  def run(args, ui_state) do
    topic = args |> List.wrap() |> Enum.join(" ") |> String.trim()
    markdown = Vibe.Docs.render(topic)

    {:events,
     [
       Vibe.Event.new(:notification_added, ui_state.session_id, %{
         level: :info,
         title: help_title(topic),
         text: markdown
       })
     ]}
  end

  defp help_title(""), do: "Vibe help"
  defp help_title(topic), do: "Vibe help: #{topic}"
end
