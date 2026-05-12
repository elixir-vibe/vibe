defmodule Vibe.Plugins.NotifyTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugins.Notify

  test "plugin handles assistant_message_added" do
    {result, _state} =
      Notify.handle_event(%{type: :assistant_message_added, data: %{}}, %{}, %{})

    assert result == :ok
  end

  test "plugin handles assistant_aborted" do
    {result, _state} =
      Notify.handle_event(
        %{type: :assistant_aborted, data: %{reason: "rate limited"}},
        %{},
        %{}
      )

    assert result == :ok
  end

  test "plugin skips notification on cancel" do
    {result, _state} =
      Notify.handle_event(
        %{type: :assistant_aborted, data: %{reason: "Cancelled."}},
        %{},
        %{}
      )

    assert result == :ok
  end

  test "unrelated events pass through" do
    {result, _state} = Notify.handle_event(%{type: :user_message_added}, %{}, %{})
    assert result == :ok
  end
end
