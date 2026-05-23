defmodule Vibe.SubscriptionTest do
  use ExUnit.Case, async: false

  defmodule FakeProvider do
    @behaviour Vibe.Subscription.Provider

    @impl true
    def usage(opts), do: {:ok, %{provider: :fake, opts: opts}}

    @impl true
    def account(opts), do: {:ok, %{account: "fake", opts: opts}}
  end

  setup do
    previous = Application.get_env(:vibe, :subscription_providers)

    on_exit(fn ->
      restore_env(previous)
    end)
  end

  test "dispatches configured usage providers" do
    Application.put_env(:vibe, :subscription_providers, %{fake: FakeProvider})

    assert Vibe.Subscription.provider(:fake) == FakeProvider

    assert Vibe.Subscription.usage(:fake, timeout: 10) ==
             {:ok, %{provider: :fake, opts: [timeout: 10]}}

    assert Vibe.Subscription.account(:fake) == {:ok, %{account: "fake", opts: []}}
  end

  test "returns a structured error for unknown providers" do
    assert Vibe.Subscription.usage(:missing) ==
             {:error, {:unknown_subscription_provider, :missing}}
  end

  defp restore_env(nil), do: Application.delete_env(:vibe, :subscription_providers)
  defp restore_env(value), do: Application.put_env(:vibe, :subscription_providers, value)
end
