defmodule Vibe.Storage.Representation.RuntimeAlertTest do
  use ExUnit.Case, async: true

  alias Vibe.Storage.Persistable
  alias Vibe.Storage.Representation.RuntimeAlert
  alias Vibe.Storage.Restorable
  alias Vibe.SystemAlarms.Alert

  test "persists and restores runtime alerts through storage protocols" do
    alert =
      Alert.from_alarm(:set, {:disk_almost_full, ~c"/tmp"}, [], at: ~U[2026-05-20 12:00:00Z])

    stored = Persistable.persist(alert)

    assert %RuntimeAlert{context: %{path: "/tmp"}} = stored
    assert Restorable.restore(stored) == alert
  end

  test "decodes the current JSON storage shape" do
    stored =
      RuntimeAlert.decode!(%{
        "id" => "disk_almost_full:/tmp",
        "source" => "beam_alarm",
        "type" => "disk_almost_full",
        "severity" => "error",
        "detail" => "detail",
        "at" => "2026-05-20T12:00:00Z",
        "context" => %{"path" => "/tmp"}
      })

    assert %RuntimeAlert{
             source: :beam_alarm,
             type: :disk_almost_full,
             severity: :error,
             context: %{path: "/tmp"}
           } = stored
  end
end
