defmodule Vibe.UI.SlashCommands.Web do
  @moduledoc "Slash command: /web — open the web console in the default browser."
  @behaviour Vibe.UI.SlashCommands.Command
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "web", description: "Open web console"}

  @impl true
  def run(_args, _ui_state) do
    url = Vibe.Web.Auth.authenticated_url()
    open_browser(url)
    {:events, [notification(:success, "Opened #{url}")]}
  end

  defp open_browser(url) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, _linux} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
    end
  rescue
    _error -> :ok
  end

  defp notification(level, text) do
    Vibe.Event.new(:notification_added, "", %{level: level, text: text})
  end
end
