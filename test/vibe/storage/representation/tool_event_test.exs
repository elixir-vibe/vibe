defmodule Vibe.Storage.Representation.ToolEventTest do
  use ExUnit.Case, async: true

  alias Vibe.Model.Content
  alias Vibe.Storage.Persistable
  alias Vibe.Storage.Representation.ToolEvent, as: StoredToolEvent
  alias Vibe.Storage.Restorable
  alias Vibe.Tool.Event

  test "persists and restores tool events through storage protocols" do
    event =
      Event.finished(id: "tool-1", name: :eval, output: %{output: "ok", output_format: :text})

    stored = Persistable.persist(event)

    assert %StoredToolEvent{name: :eval, status: :ok} = stored
    assert Restorable.restore(stored) == event
  end

  test "decodes current JSON storage shape with content parts" do
    stored =
      StoredToolEvent.decode!(%{
        "id" => "tool-1",
        "name" => "read",
        "status" => "ok",
        "output" => %{
          "parts" => [
            %{"type" => "text", "text" => "hello"},
            %{
              "type" => "image",
              "data" => "abc",
              "mime_type" => "image/png",
              "filename" => "a.png"
            }
          ]
        }
      })

    assert %StoredToolEvent{output: %{parts: [%Content.Text{}, %Content.Image{}]}} = stored
  end
end
