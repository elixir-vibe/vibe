defmodule Exy.Skill do
  @moduledoc """
  Procedural memory for Exy.

  Skills are markdown files with YAML frontmatter. They capture reusable
  workflows and can be patched as Exy learns.
  """

  @skills_dir Path.expand("~/.exy/skills")
  @allowed_name ~r/^[a-z0-9][a-z0-9._-]*$/

  @spec dir() :: String.t()
  def dir, do: @skills_dir

  @spec create(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def create(name, content, opts \\ []) do
    with :ok <- validate_name(name),
         :ok <- validate_content(content) do
      category = Keyword.get(opts, :category)
      skill_dir = skill_dir(name, category)
      path = Path.join(skill_dir, "SKILL.md")

      if File.exists?(path) and not Keyword.get(opts, :overwrite, false) do
        {:error, "skill already exists: #{name}"}
      else
        File.mkdir_p!(skill_dir)
        atomic_write(path, content)
        {:ok, path}
      end
    end
  end

  @spec patch(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def patch(name, old, new, opts \\ []) do
    with {:ok, path} <- find(name) do
      content = File.read!(path)
      replace_all = Keyword.get(opts, :replace_all, false)

      cond do
        not String.contains?(content, old) ->
          {:error, "old text not found in #{path}"}

        not replace_all and count_occurrences(content, old) > 1 ->
          {:error,
           "old text is not unique in #{path}; pass replace_all: true or use a more specific match"}

        true ->
          updated =
            if replace_all,
              do: String.replace(content, old, new),
              else: String.replace(content, old, new, global: false)

          with :ok <- validate_content(updated) do
            atomic_write(path, updated)
            {:ok, path}
          end
      end
    end
  end

  @spec find(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def find(name) do
    root = Path.expand(@skills_dir)

    case Path.wildcard(Path.join(root, "**/SKILL.md"))
         |> Enum.find(&(Path.basename(Path.dirname(&1)) == name)) do
      nil -> {:error, "skill not found: #{name}"}
      path -> {:ok, path}
    end
  end

  @spec list() :: [map()]
  def list do
    Path.wildcard(Path.join(@skills_dir, "**/SKILL.md"))
    |> Enum.map(fn path ->
      %{name: Path.basename(Path.dirname(path)), path: path, title: title(path)}
    end)
  end

  @spec validate_content(String.t()) :: :ok | {:error, String.t()}
  def validate_content(content) when is_binary(content) do
    with :ok <- validate_size(content),
         {:ok, metadata, _body} <- Exy.Skill.Frontmatter.parse(content),
         :ok <- require_frontmatter_key(metadata, "name") do
      require_frontmatter_key(metadata, "description")
    end
  end

  defp validate_size(content) do
    if String.length(content) > 100_000, do: {:error, "skill too large"}, else: :ok
  end

  defp require_frontmatter_key(metadata, key) do
    if Map.has_key?(metadata, key), do: :ok, else: {:error, "frontmatter must include #{key}"}
  end

  defp validate_name(name) do
    if is_binary(name) and Regex.match?(@allowed_name, name),
      do: :ok,
      else: {:error, "invalid skill name"}
  end

  defp skill_dir(name, nil), do: Path.join(@skills_dir, name)
  defp skill_dir(name, category), do: Path.join([@skills_dir, category, name])

  defp atomic_write(path, content) do
    tmp = path <> ".tmp-#{System.unique_integer([:positive])}"
    File.write!(tmp, content)
    File.rename!(tmp, path)
  end

  defp count_occurrences(content, needle) do
    content |> String.split(needle) |> length() |> Kernel.-(1)
  end

  defp title(path) do
    path
    |> File.read!()
    |> String.split("\n", parts: 8)
    |> Enum.find_value(fn line ->
      case Regex.run(~r/^description:\s*(.+)$/, line) do
        [_, description] -> String.trim(description, " \"'")
        _ -> nil
      end
    end)
  end
end
