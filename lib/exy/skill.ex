defmodule Exy.Skill do
  @moduledoc """
  Procedural memory for Exy.

  Skills are markdown files with YAML frontmatter. They capture reusable
  workflows and can be patched as Exy learns.
  """

  @allowed_name ~r/^[a-z0-9][a-z0-9._-]*$/

  @spec dir() :: String.t()
  def dir, do: Exy.Paths.skills_dir()

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
    case Enum.find(list(), &(&1.name == name)) do
      nil -> {:error, "skill not found: #{name}"}
      skill -> {:ok, skill.path}
    end
  end

  @spec list() :: [map()]
  def list do
    markdown_skills() ++ executable_skills()
  end

  @spec script_paths() :: [String.t()]
  def script_paths do
    [
      Application.app_dir(:exy, "priv/skills"),
      Path.join(File.cwd!(), "skills"),
      Path.join([File.cwd!(), ".exy", "skills"]),
      dir()
    ]
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end

  @spec executable() :: [Exy.Skill.Executable.t()]
  def executable, do: Exy.Skill.Loader.discover()

  @spec apis() :: [Exy.Plugin.API.t()]
  def apis, do: Exy.Skill.Loader.apis()

  @spec get(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get(name) do
    case Enum.find(list(), &(&1.name == name)) do
      nil -> {:error, "skill not found: #{name}"}
      skill -> {:ok, skill}
    end
  end

  @spec create_from_session(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def create_from_session(session_id, name, opts \\ []) do
    with :ok <- validate_name(name) do
      session = Exy.Session.Store.info(session_id)
      events = Exy.Session.Store.ui_events(session_id)

      if is_nil(session) or events == [] do
        {:error, "session not found or empty: #{session_id}"}
      else
        create_script(name, session, events, opts)
      end
    end
  end

  @spec validate_content(String.t()) :: :ok | {:error, String.t()}
  def validate_content(content) when is_binary(content) do
    with :ok <- validate_size(content),
         {:ok, metadata, _body} <- Exy.Skill.Frontmatter.parse(content),
         :ok <- require_frontmatter_key(metadata, "name") do
      require_frontmatter_key(metadata, "description")
    end
  end

  defp markdown_skills do
    Path.wildcard(Path.join(dir(), "**/SKILL.md"))
    |> Enum.map(fn path ->
      %{type: :markdown, name: Path.basename(Path.dirname(path)), path: path, title: title(path)}
    end)
  end

  defp executable_skills do
    Enum.map(executable(), fn skill ->
      %{
        type: :exs,
        name: skill.name,
        path: skill.path,
        title: Map.get(skill.metadata, :description),
        module: skill.module,
        metadata: skill.metadata,
        apis: skill.apis
      }
    end)
  end

  defp create_script(name, session, events, opts) do
    path = script_path(name, Keyword.get(opts, :category))

    if File.exists?(path) and not Keyword.get(opts, :overwrite, false) do
      {:error, "skill already exists: #{name}"}
    else
      File.mkdir_p!(Path.dirname(path))
      atomic_write(path, script_content(name, session, events))
      {:ok, path}
    end
  end

  defp script_path(name, nil), do: Path.join([dir(), name, "skill.exs"])
  defp script_path(name, category), do: Path.join([dir(), category, name, "skill.exs"])

  defp script_content(name, session, events) do
    module =
      Enum.map_join(String.split(name, ~r/[^a-zA-Z0-9]+/, trim: true), &String.capitalize/1)

    first_message = first_text(events) || "Describe when to use this skill."
    cwd = Map.fetch!(session, :cwd) || "unknown"
    session_id = Map.fetch!(session, :id)

    """
    defmodule ExySkill.#{module} do
      use Exy.Skill.Script

      skill do
        name #{inspect(name)}
        description #{inspect(first_message |> String.slice(0, 100))}
        triggers []
        alias_as __MODULE__
        examples ["#{module}.markdown()"]
      end

      @moduledoc \"\"\"
      # #{name}

      Generated from Exy session `#{session_id}` in `#{cwd}`.

      ## When to use

      #{first_message}

      ## Procedure

      - Review the source session and extract the reusable workflow.
      - Replace this generated outline with concrete steps.
      - Add helper functions below when the workflow benefits from executable checks.
      \"\"\"
    end
    """
  end

  defp first_text(events) do
    Enum.find_value(events, fn
      {_seq, %{data: %{text: text}}} when is_binary(text) and text != "" -> text
      _event -> nil
    end)
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

  defp skill_dir(name, nil), do: Path.join(dir(), name)
  defp skill_dir(name, category), do: Path.join([dir(), category, name])

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
