defmodule Vibe.CLI.BootTest do
  use ExUnit.Case, async: false

  alias Vibe.CLI.Boot

  describe "server_foreground?/1" do
    test "only foreground server start owns the web endpoint" do
      assert Boot.server_foreground?(parsed(["server", "start", "--foreground"]))
      refute Boot.server_foreground?(parsed(["server", "start"]))
      refute Boot.server_foreground?(parsed([]))
      refute Boot.server_foreground?(parsed(["a", "session-id"]))
    end

    test "foreground server restart also owns the web endpoint" do
      assert Boot.server_foreground?(parsed(["server", "restart", "--foreground"]))
      refute Boot.server_foreground?(parsed(["server", "restart"]))
      refute Boot.server_foreground?(parsed(["server", "status"]))
    end
  end

  describe "configure_application_start/1" do
    setup do
      previous_web = Application.get_env(:vibe, :web)
      previous_port = Application.get_env(:vibe, :web_port)

      on_exit(fn ->
        restore_env(:web, previous_web)
        restore_env(:web_port, previous_port)
      end)
    end

    test "disables the endpoint for client invocations" do
      assert :ok = Boot.configure_application_start(parsed([]))
      refute Application.get_env(:vibe, :web)
    end

    test "keeps the endpoint enabled for the foreground server" do
      assert :ok = Boot.configure_application_start(parsed(["server", "start", "--foreground"]))
      assert Application.get_env(:vibe, :web)
    end

    test "applies the requested web port before the application starts" do
      assert :ok =
               Boot.configure_application_start(
                 parsed(["server", "start", "--foreground", "--port", "9876"])
               )

      assert Application.get_env(:vibe, :web_port) == 9876
    end
  end

  defp parsed(argv), do: Vibe.CLI.Parser.parse(argv)

  defp restore_env(key, nil), do: Application.delete_env(:vibe, key)
  defp restore_env(key, value), do: Application.put_env(:vibe, key, value)
end
