defmodule Vibe.Gateway.SourceTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.Source

  test "builds source identity with normalized scalar fields" do
    source =
      Source.new(:telegram,
        chat_id: -100,
        chat_type: "group",
        user_id: 42,
        thread_id: 7,
        chat_name: "Vibe"
      )

    assert source.chat_id == "-100"
    assert source.chat_type == :group
    assert source.user_id == "42"
    assert source.thread_id == "7"
    assert Source.description(source) == "group: Vibe, thread: 7"
  end

  test "rejects invalid chat types" do
    assert_raise ArgumentError, fn ->
      Source.new(:telegram, chat_id: "1", chat_type: "unknown")
    end
  end
end
