defmodule Exy.Skill.Frontmatter do
  @moduledoc "YAML frontmatter parser for skill files."
  @spec parse(String.t()) :: {:ok, map(), String.t()} | {:error, String.t()}
  def parse(content) when is_binary(content) do
    with {:ok, yaml, body} <- split(content),
         {:ok, metadata} <- parse_yaml(yaml) do
      {:ok, metadata, body}
    end
  end

  defp split("---\n" <> rest) do
    case :binary.split(rest, "\n---", [:global]) do
      [yaml, body] -> {:ok, yaml, String.trim_leading(body, "\n")}
      [_] -> {:error, "frontmatter must be closed with ---"}
      [_yaml | _extra] -> {:error, "frontmatter must contain one closing ---"}
    end
  end

  defp split(_content), do: {:error, "skill must start with frontmatter"}

  defp parse_yaml(yaml) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, metadata} when is_map(metadata) -> {:ok, metadata}
      {:ok, _metadata} -> {:error, "frontmatter must be a YAML mapping"}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end
end
