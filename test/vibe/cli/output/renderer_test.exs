defmodule Vibe.CLI.Output.RendererTest do
  use ExUnit.Case, async: true

  alias Vibe.CLI.Output.Renderer

  test "renders session listings only when session fields are present" do
    output =
      Renderer.render([
        %{
          id: "session-1",
          updated_at: "2026-05-22T10:20:30Z",
          live?: true,
          status: :idle,
          first_message: "hello"
        }
      ])

    assert output =~ "UPDATED"
    assert output =~ "session-1"
    assert output =~ "hello"
  end

  test "does not classify arbitrary maps with ids as sessions" do
    output = Renderer.render([%{id: "item-1", name: "not a session"}])

    refute output =~ "UPDATED"
    assert output =~ "not a session"
  end
end
