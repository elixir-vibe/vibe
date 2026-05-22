defmodule Vibe.CLI.Commands.Connect.KnownNodesViewTest do
  use ExUnit.Case, async: true

  alias Vibe.CLI.Commands.Connect.KnownNodesView

  test "renders empty state" do
    assert KnownNodesView.render([]) =~ "No known nodes"
  end

  test "renders known nodes with optional labels and default transport" do
    output =
      KnownNodesView.render([
        %{"node" => "host:22", "transport" => "ssh", "label" => "prod"},
        %{"node" => "node@host"}
      ])

    assert output =~ "Known nodes:"
    assert output =~ "host:22 [ssh] (prod)"
    assert output =~ "node@host [distribution]"
  end
end
