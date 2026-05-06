defmodule Vibe.MemoryManagerTest do
  use ExUnit.Case, async: false

  defmodule ExternalProvider do
    use Vibe.Memory.Provider
  end

  defmodule OtherExternalProvider do
    use Vibe.Memory.Provider
  end

  test "memory manager starts with builtin provider and allows one external provider" do
    assert Vibe.Memory.BuiltinProvider in Vibe.Memory.Manager.providers()

    on_exit(fn -> Vibe.Memory.Manager.unload(ExternalProvider) end)

    case Vibe.Memory.Manager.load(ExternalProvider) do
      :ok -> :ok
      {:error, :already_loaded} -> :ok
    end

    assert {:error, :external_provider_already_loaded} =
             Vibe.Memory.Manager.load(OtherExternalProvider)
  end
end
