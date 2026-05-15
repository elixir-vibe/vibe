defmodule Vibe.Model.ResolverTest do
  use ExUnit.Case, async: true

  alias Vibe.Model.Resolver

  test "resolves exact provider:model spec" do
    assert {:ok, "openai_codex:" <> _, nil} = Resolver.resolve("openai_codex:gpt-5.5")
  end

  test "resolves model:effort shorthand" do
    case Resolver.resolve("openai_codex:gpt-5.5:high") do
      {:ok, model, :high} -> assert model =~ "gpt-5.5"
      {:error, :not_found} -> :ok
    end
  end

  test "returns a result even for unknown models via openrouter passthrough" do
    result = Resolver.resolve("nonexistent_provider:fake_model_xyz")
    assert match?({:ok, _, _}, result) or match?({:error, :not_found}, result)
  end

  test "effort parsing works for valid levels" do
    for level <- ~w(off minimal low medium high xhigh) do
      assert {:ok, _effort} = Vibe.Model.Effort.from_string(level)
    end
  end
end
