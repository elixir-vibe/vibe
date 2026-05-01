defmodule Exy.UI.SlashCommands.Help do
  @moduledoc "Internal implementation module."
  @behaviour Exy.UI.SlashCommands.Command

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
    markdown = Exy.Docs.render(topic)

    {:events,
     [
       Exy.UI.Event.new(:notification_added, ui_state.session_id, %{
         level: :info,
         title: help_title(topic),
         text: markdown
       })
     ]}
  end

  defp help_title(""), do: "Exy help"
  defp help_title(topic), do: "Exy help: #{topic}"
end
