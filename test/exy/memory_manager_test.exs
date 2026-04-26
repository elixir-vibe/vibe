defmodule Exy.MemoryManagerTest do
  use ExUnit.Case, async: false

  defmodule ExternalProvider do
    use Exy.Memory.Provider
  end

  defmodule OtherExternalProvider do
    use Exy.Memory.Provider
  end

  test "memory manager starts with builtin provider and allows one external provider" do
    assert Exy.Memory.BuiltinProvider in Exy.Memory.Manager.providers()

    on_exit(fn -> Exy.Memory.Manager.unload(ExternalProvider) end)

    case Exy.Memory.Manager.load(ExternalProvider) do
      :ok -> :ok
      {:error, :already_loaded} -> :ok
    end

    assert {:error, :external_provider_already_loaded} =
             Exy.Memory.Manager.load(OtherExternalProvider)
  end
end
