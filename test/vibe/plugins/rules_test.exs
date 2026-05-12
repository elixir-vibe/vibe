defmodule Vibe.Plugins.RulesTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugins.Rules
  alias Vibe.Plugins.Rules.Loader

  setup do
    dir = Path.join(System.tmp_dir!(), "vibe-rules-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "loads markdown files from a directory", %{dir: dir} do
    File.write!(Path.join(dir, "style.md"), "Use pattern matching.")
    File.write!(Path.join(dir, "naming.md"), "Use snake_case.")

    rules = Loader.load_dir(dir)
    assert length(rules) == 2
    assert Enum.any?(rules, &(&1.body == "Use pattern matching."))
  end

  test "parses frontmatter with model filter", %{dir: dir} do
    File.write!(Path.join(dir, "codex.md"), """
    ---
    models: "openai_codex/*"
    ---
    Codex-specific rule.
    """)

    [rule] = Loader.load_dir(dir)
    assert rule.models == ["openai_codex/*"]
    assert rule.body == "Codex-specific rule."
  end

  test "parses frontmatter with model list", %{dir: dir} do
    File.write!(Path.join(dir, "multi.md"), """
    ---
    models: ["openai_codex/*", "anthropic/*"]
    ---
    Multi-model rule.
    """)

    [rule] = Loader.load_dir(dir)
    assert rule.models == ["openai_codex/*", "anthropic/*"]
  end

  test "rules without frontmatter apply to all models", %{dir: dir} do
    File.write!(Path.join(dir, "general.md"), "Always be concise.")
    [rule] = Loader.load_dir(dir)
    assert is_nil(rule.models)
  end

  test "filter_for_model respects glob patterns", %{dir: dir} do
    File.write!(Path.join(dir, "codex.md"), "---\nmodels: \"openai_codex/*\"\n---\nCodex only.")
    File.write!(Path.join(dir, "all.md"), "For everyone.")

    rules = Loader.load_dir(dir)
    assert length(Loader.filter_for_model(rules, "openai_codex:gpt-5.5")) == 2
    assert length(Loader.filter_for_model(rules, "anthropic:claude-sonnet-4")) == 1
  end

  test "scans subdirectories recursively", %{dir: dir} do
    sub = Path.join(dir, "elixir")
    File.mkdir_p!(sub)
    File.write!(Path.join(sub, "style.md"), "Elixir style.")

    assert [rule] = Loader.load_dir(dir)
    assert rule.body == "Elixir style."
  end

  test "returns empty list for missing directory" do
    assert Loader.load_dir("/nonexistent/path") == []
  end

  test "plugin system_prompt returns formatted block", %{dir: dir} do
    File.write!(Path.join(dir, "test.md"), "Test rule.")
    rules = Loader.load_dir(dir)

    {block, _state} = Rules.system_prompt(%{model: nil}, %{rules: rules})
    assert block =~ "Instructions from:"
    assert block =~ "Test rule."
  end

  test "plugin system_prompt filters by model", %{dir: dir} do
    File.write!(Path.join(dir, "codex.md"), "---\nmodels: \"openai_codex/*\"\n---\nCodex only.")
    rules = Loader.load_dir(dir)

    {block, _state} = Rules.system_prompt(%{model: "anthropic:claude"}, %{rules: rules})
    assert is_nil(block)

    {block, _state} = Rules.system_prompt(%{model: "openai_codex:gpt-5.5"}, %{rules: rules})
    assert block =~ "Codex only."
  end
end
