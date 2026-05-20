defmodule Vibe.Remote.KnownNodesTest do
  use ExUnit.Case, async: false

  alias Vibe.Remote.KnownNodes

  setup do
    dir =
      Path.join(System.tmp_dir!(), "vibe-known-nodes-test-#{System.unique_integer([:positive])}")

    original_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    on_exit(fn ->
      if original_home,
        do: Application.put_env(:vibe, :home_dir, original_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf!(dir)
    end)

    :ok
  end

  test "persists transport metadata" do
    assert :ok = KnownNodes.add("vibe@example", label: "example", transport: "distribution")

    assert [
             %{
               "node" => "vibe@example",
               "label" => "example",
               "transport" => "distribution"
             }
           ] = KnownNodes.list()
  end
end
