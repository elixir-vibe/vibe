defmodule Vibe.Plugins.QuestionTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugins.Question

  test "plugin provides the question action" do
    assert [Vibe.Plugins.Question.Action] = Question.actions(%{})
  end

  test "register and pop waiter" do
    Question.register_waiter("test-session", self())

    {result, _state} =
      Question.handle_event(
        %{type: :selector_confirmed, data: %{selector: :question_selector, item: "Option A"}},
        %{session_id: "test-session"},
        %{}
      )

    assert result == :ok
    assert_receive {:question_answered, "Option A"}
  end

  test "cancel sends cancelled message" do
    Question.register_waiter("cancel-session", self())

    {result, _state} =
      Question.handle_event(
        %{type: :selector_closed},
        %{session_id: "cancel-session"},
        %{}
      )

    assert result == :ok
    assert_receive {:question_cancelled}
  end

  test "no waiter is safe" do
    {result, _state} =
      Question.handle_event(
        %{type: :selector_confirmed, data: %{selector: :question_selector, item: "X"}},
        %{session_id: "no-waiter"},
        %{}
      )

    assert result == :ok
  end

  test "unrelated events pass through" do
    {result, _state} = Question.handle_event(%{type: :user_message_added}, %{}, %{})
    assert result == :ok
  end
end
