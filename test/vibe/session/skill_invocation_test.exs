defmodule Vibe.Session.SkillInvocationTest do
  use ExUnit.Case, async: false

  alias Vibe.Session
  alias Vibe.UI.Command

  test "slash skill command submits expanded skill content to the model" do
    parent = self()

    ask = fn text, _opts ->
      send(parent, {:asked, text})
      {:ok, "ok"}
    end

    {:ok, session} = Session.start_link(ask_fun: ask, persist?: false)

    :ok =
      Session.dispatch(
        session,
        Command.new(:slash_command_submitted, %{
          command: "skill:session-to-skill",
          args: "make it reusable"
        })
      )

    assert_receive {:asked, text}, 2_000
    assert text =~ ~s(<skill name="session-to-skill")
    assert text =~ "make it reusable"
    refute text =~ "selected skill:"
    refute text =~ "## Active skills"
  end
end
