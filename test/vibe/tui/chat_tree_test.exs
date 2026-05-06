defmodule Vibe.TUI.ChatTreeTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{ChatTree, Node, RenderTree}
  alias Vibe.UI.Block.{Footer, NotificationList, Overlay, PluginWidget, ToolCall, UserMessage}

  test "builds stable ordered nodes for chat sections" do
    tree = ChatTree.build(view(picker: picker(), notifications: notifications()))

    assert Enum.map(tree.nodes, & &1.id) == [
             {:message, "m1"},
             {:spacer, :body},
             {:tool_call, "tool-1"},
             {:plugin_widget, "above"},
             {:plugin_widget, "side"},
             {:spacer, :notice_margin},
             :notifications,
             {:picker, :autocomplete, :erlang.phash2(picker().props)},
             {:spacer, :footer_margin},
             :footer,
             {:plugin_widget, "below"},
             {:overlay, :diagnostic, :erlang.phash2(diagnostic_overlay())}
           ]
  end

  test "omits confirmation overlays from chat tree" do
    tree = ChatTree.build(view(overlays: [confirmation_overlay(), diagnostic_overlay()]))

    refute Enum.any?(tree.nodes, &match?(%RenderTree.Node{id: {:overlay, :confirmation, _}}, &1))
    assert Enum.any?(tree.nodes, &match?(%RenderTree.Node{id: {:overlay, :diagnostic, _}}, &1))
  end

  test "converts tree to TUI node without changing order" do
    tui_node = view() |> ChatTree.build() |> ChatTree.to_tui_node()

    assert %Node{type: :vertical, children: children} = tui_node

    assert Enum.map(children, & &1.type) == [
             :message,
             :spacer,
             :tool,
             :plugin_widget,
             :plugin_widget,
             :spacer,
             :footer,
             :plugin_widget,
             :overlay
           ]
  end

  defp view(opts \\ []) do
    %{
      body: [message(), tool()],
      footer: footer(),
      overlays: Keyword.get(opts, :overlays, [confirmation_overlay(), diagnostic_overlay()]),
      notifications: Keyword.get(opts, :notifications),
      picker: Keyword.get(opts, :picker),
      plugin_widgets: %{
        above_editor: [plugin("above", :above_editor)],
        sidebar: [plugin("side", :sidebar)],
        below_editor: [plugin("below", :below_editor)]
      }
    }
  end

  defp message, do: %UserMessage{id: "m1", text: "hello", at: ~U[2026-01-01 00:00:00Z]}

  defp tool do
    %ToolCall{id: "tool-1", name: :eval, status: :ok, args: %{code: "1 + 1"}, output: "2"}
  end

  defp footer,
    do: %Footer{cwd: "/tmp", model: "model-a", effort: :medium, session_id: "s1", status: :idle}

  defp notifications, do: %NotificationList{items: [%{message: "indexed"}]}

  defp plugin(id, placement),
    do: %PluginWidget{id: id, type: :status, props: %{}, placement: placement, version: 1}

  defp picker, do: %Node{type: :autocomplete, props: %{query: "/model"}}
  defp confirmation_overlay, do: %Overlay{kind: :confirmation, data: %{title: "Confirm"}}
  defp diagnostic_overlay, do: %Overlay{kind: :diagnostic, data: %{message: "ok"}}
end
