defmodule Vibe.Plugins.Rules do
  @moduledoc """
  Plugin: load rule files from `~/.vibe/rules/` into the system prompt.

  Rules are Markdown files scanned recursively. See `Vibe.Rules` for
  frontmatter filtering by model.
  """
  use Vibe.Plugin

  alias Vibe.Plugins.Rules.Loader

  @impl true
  def init(opts) do
    rules = Loader.load()
    {:ok, %{rules: rules, opts: opts}}
  end

  @impl true
  def system_prompt(%{model: model}, %{rules: rules} = state) do
    block =
      rules
      |> Loader.filter_for_model(model)
      |> Enum.map_join("\n\n", fn rule -> "Instructions from: #{rule.path}\n#{rule.body}" end)

    {non_empty(block), state}
  end

  defp non_empty(""), do: nil
  defp non_empty(text), do: text
end
