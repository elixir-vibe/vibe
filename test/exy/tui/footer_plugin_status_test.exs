defmodule Exy.TUI.FooterPluginStatusTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Theme, Widget, Width}

  test "footer renders sorted plugin status line" do
    plain =
      DSL.footer(%{
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
