defmodule Vibe.Skill do
  @moduledoc """
  Procedural memory for Vibe.

  Skills are markdown files with YAML frontmatter. They capture reusable
  workflows and can be patched as Vibe learns.
  """

  alias Vibe.Plugin.API
  alias Vibe.Skill.{Executable, Loader}

  @allowed_name ~r/^[a-z0-9][a-z0-9._-]*$/
  @default_context_max_bytes 6_000
  @max_skill_file_chars 100_000

  @spec dir() :: String.t()
  def dir, do: Vibe.Paths.skills_dir()

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
      Application.app_dir(:vibe, "priv/skills"),
      Path.join(File.cwd!(), "skills"),
      Path.join([File.cwd!(), ".vibe", "skills"]),
      dir()
    ]
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end

  @spec executable() :: [Executable.t()]
  def executable, do: Loader.discover()

  @spec apis() :: [API.t()]
  def apis, do: Loader.apis()

  @spec get(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get(name) do
    case Enum.find(list(), &(&1.name == name)) do
      nil -> {:error, "skill not found: #{name}"}
      skill -> {:ok, skill}
    end
  end

  @spec match(String.t(), keyword()) :: [map()]
  def match(text, opts \\ []) when is_binary(text) do
    limit = Keyword.get(opts, :limit, 3)
    normalized = normalize_text(text)

    list()
    |> Enum.map(&Map.put(&1, :score, skill_score(&1, normalized)))
    |> Enum.filter(&(&1.score > 0))
    |> Enum.sort_by(&{-&1.score, &1.name})
    |> Enum.take(limit)
  end

  @spec invocation(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def invocation(name, args \\ "") when is_binary(name) and is_binary(args) do
    with {:ok, skill} <- get(name) do
      block =
        [
          ~s(<skill name="),
          escape_xml(skill.name),
          ~s(" location="),
          escape_xml(skill.path),
          ~s(">\n),
          "References are relative to ",
          escape_xml(Path.dirname(skill.path)),
          ".\n\n",
          skill_body(skill),
          "\n</skill>"
        ]
        |> IO.iodata_to_binary()

      args = String.trim(args)
      {:ok, if(args == "", do: block, else: block <> "\n\n" <> args)}
    end
  end

  @spec context(String.t(), keyword()) :: String.t()
  def context(text, opts \\ []) when is_binary(text) do
    case match(text, opts) do
      [] -> ""
      skills -> active_skills_markdown(skills, opts)
    end
  end

  @spec create_from_session(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def create_from_session(session_id, name, opts \\ []) do
    with :ok <- validate_name(name) do
      session = Vibe.Session.Store.info(session_id)
      events = Vibe.Session.Store.ui_events(session_id)

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
         {:ok, metadata, _body} <- Vibe.Skill.Frontmatter.parse(content),
         :ok <- require_frontmatter_key(metadata, "name") do
      require_frontmatter_key(metadata, "description")
    end
  end

  defp markdown_skills do
    Path.wildcard(Path.join(dir(), "**/SKILL.md"))
    |> Enum.map(fn path ->
      {metadata, markdown} = markdown_skill_content(path)

      %{
        type: :markdown,
        name: Map.get(metadata, "name", Path.basename(Path.dirname(path))),
        path: path,
        title: Map.get(metadata, "description") || title(path),
        metadata: metadata,
        markdown: markdown,
        apis: []
      }
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
        markdown: skill.markdown,
        apis: skill.apis
      }
    end)
  end

  defp active_skills_markdown(skills, opts) do
    body =
      skills
      |> Enum.map(&skill_markdown(&1, opts))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    if body == "" do
      ""
    else
      """
      ## Active skills

      The following skills are relevant background instructions. Follow them when applicable; do not mention them unless useful.

      #{body}
      """
      |> String.trim()
    end
  end

  defp skill_markdown(skill, opts) do
    max_bytes = Keyword.get(opts, :max_bytes, @default_context_max_bytes)

    [
      "### ",
      skill.name,
      "\n\n",
      skill_description(skill),
      skill_api_markdown(skill),
      "\n\n",
      skill_body(skill)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
    |> truncate_markdown(max_bytes)
  end

  defp skill_description(%{title: title}) when is_binary(title) and title != "", do: title <> "\n"
  defp skill_description(_skill), do: ""

  defp skill_api_markdown(%{apis: []}), do: ""

  defp skill_api_markdown(%{apis: apis}) do
    examples =
      apis
      |> Enum.flat_map(& &1.examples)
      |> Enum.reject(&(&1 == ""))

    aliases = Enum.map_join(apis, ", ", &"`#{&1.alias}`")

    case examples do
      [] ->
        "\nAvailable eval aliases: #{aliases}."

      examples ->
        "\nAvailable eval aliases: #{aliases}.\n\nExamples:\n" <>
          Enum.map_join(examples, "\n", &"- `#{&1}`")
    end
  end

  defp skill_body(%{type: :exs, module: module} = skill) do
    if function_exported?(module, :prompt_context, 1) do
      module.prompt_context(%{skill: skill})
    else
      Map.get(skill, :markdown, "")
    end
  rescue
    _exception -> Map.get(skill, :markdown, "")
  end

  defp skill_body(skill), do: Map.get(skill, :markdown, "")

  defp escape_xml(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp truncate_markdown(text, max_bytes) when byte_size(text) <= max_bytes, do: text

  defp truncate_markdown(text, max_bytes),
    do: text |> String.slice(0, max_bytes) |> Kernel.<>("...")

  defp skill_score(skill, normalized_text) do
    trigger_score(skill, normalized_text) + name_score(skill, normalized_text)
  end

  defp trigger_score(skill, normalized_text) do
    skill
    |> skill_triggers()
    |> Enum.reduce(0, fn trigger, score ->
      normalized_trigger = normalize_text(trigger)

      if normalized_trigger != "" and String.contains?(normalized_text, normalized_trigger),
        do: score + 10,
        else: score
    end)
  end

  defp name_score(skill, normalized_text) do
    normalized_name = skill.name |> String.replace(["-", "_"], " ") |> normalize_text()

    if normalized_name != "" and String.contains?(normalized_text, normalized_name),
      do: 5,
      else: 0
  end

  defp skill_triggers(%{metadata: metadata}) do
    metadata
    |> get_metadata(:triggers)
    |> List.wrap()
    |> Enum.filter(&is_binary/1)
  end

  defp get_metadata(metadata, key) when is_atom(key),
    do: Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end

  defp markdown_skill_content(path) do
    case path |> File.read!() |> Vibe.Skill.Frontmatter.parse() do
      {:ok, metadata, markdown} -> {metadata, markdown}
      {:error, _reason} -> {%{}, ""}
    end
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
    defmodule VibeSkill.#{module} do
      use Vibe.Skill.Script

      skill do
        name #{inspect(name)}
        description #{inspect(first_message |> String.slice(0, 100))}
        triggers []
        alias_as __MODULE__
        examples ["#{module}.markdown()"]
      end

      @moduledoc \"\"\"
      # #{name}

      Generated from Vibe session `#{session_id}` in `#{cwd}`.

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
    if String.length(content) > @max_skill_file_chars, do: {:error, "skill too large"}, else: :ok
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
