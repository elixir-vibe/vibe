defmodule Exy.TUI.AppTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.App

  test "coordinates editor submit and ui events" do
    ask = fn text, opts ->
      if opts[:on_result] do
        opts[:on_result].("streamed ")
        opts[:on_result].(text)
      end

      {:ok, %{message: %{content: [%{type: :text, text: "streamed " <> text}]}}}
    end

    {:ok, app} = App.start_link(ask_fun: ask, width: 80, height: 20)

    :ok = App.key(app, {:insert, "hello"})
    :ok = App.key(app, :submit)
    Process.sleep(50)

    snapshot = App.snapshot(app)
    assert snapshot.editor.text == ""
    assert Enum.any?(snapshot.ui.messages, &(&1.role == :assistant))
    assert snapshot.width == 80
  end

  test "tracks resize" do
    {:ok, app} = App.start_link()
    :ok = App.resize(app, 120, 40)
    assert %{width: 120, height: 40} = App.snapshot(app)
  end
end
