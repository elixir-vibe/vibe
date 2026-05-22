defmodule Vibe.TUI.FooterPluginStatusTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI

  alias Vibe.Terminal.{Theme, Width}
  alias Vibe.TUI.Widget

  test "footer renders local session label before server active count is known" do
    plain =
      TUI.footer(%{
        cwd: File.cwd!(),
        session_id: "session",
        model: "model",
        status: :idle,
        usage: %{total_tokens: 0},
        active_sessions: nil,
        plugin_statuses: %{}
      })
      |> Widget.render(80, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "local"
    refute plain =~ "server starting"
  end

  test "footer renders sorted plugin status line" do
    plain =
      TUI.footer(%{
        cwd: File.cwd!(),
        session_id: "session",
        model: "model",
        status: :idle,
        usage: %{total_tokens: 0},
        plugin_statuses: %{"z" => "Zed\nStatus", "a" => "Alpha"}
      })
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.at(plain, 1) == "Alpha Zed Status"
  end
end
