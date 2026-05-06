defmodule Exy.Gateway.RuntimeTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.{Message, Runtime, Source}

  defmodule Backend do
    @behaviour Exy.Gateway.Backend

    defstruct allow?: true

    @impl true
    def load_config(opts), do: {:ok, struct!(__MODULE__, opts)}

    @impl true
    def normalize(:ignore, _config), do: :ignore
    def normalize(:bad, _config), do: {:error, :bad_update}

    def normalize(text, _config) when is_binary(text) do
      source = Source.new(:telegram, chat_id: "1", chat_type: :dm, user_id: "2")
      {:ok, %{message: Message.new(source, text: text), trigger: %{}}}
    end

    @impl true
    def authorized?(_message, _trigger, config), do: config.allow?

    @impl true
    def outbound_adapter(_config), do: Exy.Gateway.Telegram.Adapter
  end

  test "normalizes authorized updates and dispatches messages" do
    parent = self()

    dispatch = fn message, opts ->
      send(parent, {:dispatch, message.text, opts})
      {:ok, "session"}
    end

    assert {:ok, runtime} =
             Runtime.start_link(
               backend: Backend,
               backend_opts: [allow?: true],
               dispatch_fun: dispatch,
               dispatch_opts: [bridge?: false, session_key_opts: [group_sessions_per_user: false]]
             )

    assert :ok = Runtime.submit(runtime, "hello")

    assert_receive {:dispatch, "hello",
                    [bridge?: false, session_key_opts: [group_sessions_per_user: false]]}

    assert %{accepted: 1, ignored: 0, rejected: 0, failed: 0} = Runtime.stats(runtime)
  end

  test "tracks ignored, rejected, and failed updates" do
    assert {:ok, runtime} = Runtime.start_link(backend: Backend, backend_opts: [allow?: false])

    Runtime.submit(runtime, "nope")
    Runtime.submit(runtime, :ignore)
    Runtime.submit(runtime, :bad)

    eventually(fn ->
      assert %{accepted: 0, ignored: 1, rejected: 1, failed: 1} = Runtime.stats(runtime)
    end)
  end

  defp eventually(fun) do
    fun.()
  rescue
    ExUnit.AssertionError ->
      Process.sleep(20)
      fun.()
  end
end
