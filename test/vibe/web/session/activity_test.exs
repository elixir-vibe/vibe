defmodule Vibe.Web.Session.ActivityTest do
  use ExUnit.Case, async: true

  alias Vibe.Web.Session.Activity

  test "working detects status streams and running tools" do
    refute Activity.working?(%{status: :idle, streaming_message: nil, pending_tools: %{}})
    assert Activity.working?(%{status: :working, streaming_message: nil, pending_tools: %{}})
    assert Activity.working?(%{status: :running, streaming_message: nil, pending_tools: %{}})
    assert Activity.working?(%{status: :idle, streaming_message: %{text: ""}, pending_tools: %{}})

    assert Activity.working?(%{
             status: :idle,
             streaming_message: nil,
             pending_tools: %{"1" => %{status: :running}}
           })

    assert Activity.working?(%{
             status: :idle,
             streaming_message: nil,
             pending_tools: %{"1" => %{status: nil}}
           })
  end

  test "visible stream requires non-blank text" do
    refute Activity.visible_stream?(%{streaming_message: nil})
    refute Activity.visible_stream?(%{streaming_message: %{text: "  "}})
    assert Activity.visible_stream?(%{streaming_message: %{text: "hello"}})
  end

  test "activity labels prioritize running tools then visible stream then working" do
    assert Activity.activity_label(%{
             status: :working,
             streaming_message: %{text: "hello"},
             pending_tools: %{"1" => %{status: :running, name: :read_file}}
           }) == "Running read file…"

    assert Activity.activity_label(%{
             status: :working,
             streaming_message: %{text: "hello"},
             pending_tools: %{}
           }) == "Writing…"

    assert Activity.activity_label(%{
             status: :working,
             streaming_message: %{text: ""},
             pending_tools: %{}
           }) == "Thinking…"

    assert Activity.activity_label(%{status: :idle, streaming_message: nil, pending_tools: %{}}) ==
             nil
  end
end
