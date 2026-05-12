defmodule Vibe.Plugins.Rules.Loader do
  @moduledoc """
  Load rule files from `~/.vibe/rules/` into the system prompt.

  Rule files are Markdown files (`.md`) scanned recursively. Optional YAML
  frontmatter controls filtering:

      ---
      models: "openai_codex/*"
      ---
      Always use pattern matching instead of if/else chains.

  Rules without `models:` frontmatter apply to all models. The `models:`
  field accepts a glob pattern or list of patterns matched against `provider:model_id`.

  Loaded automatically by `Vibe.Plugins.Rules`.
  """

  @type rule :: %{
          path: String.t(),
          body: String.t(),
          models: [String.t()] | nil
        }

  @spec rules_dir() :: String.t()
  def rules_dir, do: Vibe.Paths.rules_dir()

  @spec load() :: [rule()]
  def load, do: load_dir(rules_dir())

  @spec load_dir(String.t()) :: [rule()]
  def load_dir(dir) do
    if File.dir?(dir) do
      dir
      |> Path.join("**/*.md")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&parse_rule/1)
    else
      []
    end
  end

  @spec system_prompt_block(String.t() | nil) :: String.t()
  def system_prompt_block(model \\ nil) do
    load()
    |> filter_for_model(model)
    |> Enum.map_join("\n\n", fn rule -> "Instructions from: #{rule.path}\n#{rule.body}" end)
  end

  @spec filter_for_model([rule()], String.t() | nil) :: [rule()]
  def filter_for_model(rules, nil), do: rules

  def filter_for_model(rules, model) when is_binary(model) do
    Enum.filter(rules, fn rule ->
      is_nil(rule.models) or Enum.any?(rule.models, &glob_match?(&1, model))
    end)
  end

  defp parse_rule(path) do
    content = File.read!(path)
    {frontmatter, body} = split_frontmatter(content)

    %{
      path: path,
      body: String.trim(body),
      models: parse_models(frontmatter)
    }
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] -> {fm, body}
      _no_close -> {"", rest}
    end
  end

  defp split_frontmatter(content), do: {"", content}

  defp parse_models(""), do: nil

  defp parse_models(frontmatter) do
    case Regex.scan(~r/^models:\s*(.+)$/m, frontmatter) do
      [[_match, value]] -> parse_model_value(String.trim(value))
      _no_match -> nil
    end
  end

  defp parse_model_value("[" <> _ = value) do
    value
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> String.split(",")
    |> Enum.map(&(&1 |> String.trim() |> String.trim("\"")))
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_model_value(value), do: [String.trim(value, "\"")]

  defp glob_match?(pattern, string) do
    normalized = String.replace(string, ":", "/")

    pattern
    |> glob_to_regex()
    |> then(&(Regex.match?(&1, string) or Regex.match?(&1, normalized)))
  end

  defp glob_to_regex(pattern) do
    pattern
    |> Regex.escape()
    |> String.replace("\\*", ".*")
    |> then(&Regex.compile!("^#{&1}$"))
  end
end
