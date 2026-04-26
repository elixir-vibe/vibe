defmodule Exy.UI.SlashCommands.Attach do
  @moduledoc false

  @behaviour Exy.UI.SlashCommand

  alias Exy.UI.Event
  alias Exy.UI.SlashCommands.Sessions

  @impl true
  def spec, do: %{name: "attach", aliases: ["a"], description: "Attach by session id"}

  @impl true
  def run(args, ui_state) do
    case String.trim(args) do
      "" ->
        Sessions.run("", ui_state)

      session_id ->
        {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}
    end
  end
end
