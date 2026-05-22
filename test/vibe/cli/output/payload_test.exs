defmodule Vibe.CLI.Output.PayloadTest do
  use ExUnit.Case, async: true

  alias Vibe.CLI.Output.Payload

  test "builds human and JSON success payloads" do
    assert {:stdio, human, :ok} = Payload.build(:ok, [])
    assert human =~ "ok"

    assert {:stdio, json, :ok} = Payload.build({:ok, [%{id: "s"}]}, mode: "json")
    assert Jason.decode!(json)["results"] == [%{"id" => "s"}]

    assert {:stdio, json, :ok} = Payload.build({:ok, %{id: "s"}}, mode: "json")
    assert Jason.decode!(json)["result"] == %{"id" => "s"}
  end

  test "routes errors to stderr for human mode and stdio for JSON" do
    assert {:stderr, "error: :bad", {:error, :bad}} = Payload.build({:error, :bad}, [])

    assert {:stdio, json, {:error, :bad}} = Payload.build({:error, :bad}, mode: "json")
    assert Jason.decode!(json) == %{"ok" => false, "error" => ":bad"}
  end
end
