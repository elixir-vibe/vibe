defmodule Vibe.Skill.Loader do
  @moduledoc "Skill discovery from priv, project, and user directories."
  alias Vibe.Plugin.API
  alias Vibe.Skill.Executable

  @spec load_file(String.t()) :: {:ok, [Executable.t()]} | {:error, term()}
  def load_file(path) when is_binary(path) do
    path = Path.expand(path)
    key = {__MODULE__, :file, path}
    mtime = File.stat!(path).mtime

    case :persistent_term.get(key, nil) do
      {^mtime, skills} ->
        {:ok, skills}

      _stale ->
        modules =
          path
          |> Code.compile_file()
          |> Enum.map(&elem(&1, 0))
          |> Enum.filter(&skill_module?/1)

        skills = Enum.map(modules, &executable(&1, path))
        :persistent_term.put(key, {mtime, skills})
        {:ok, skills}
    end
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end

  @spec load_dir(String.t()) :: {:ok, [Executable.t()]} | {:error, term()}
  def load_dir(dir) when is_binary(dir) do
    dir
    |> files()
    |> Enum.reduce_while({:ok, []}, fn file, {:ok, acc} ->
      case load_file(file) do
        {:ok, skills} -> {:cont, {:ok, skills ++ acc}}
        {:error, reason} -> {:halt, {:error, {file, reason}}}
      end
    end)
    |> case do
      {:ok, skills} -> {:ok, Enum.reverse(skills)}
      error -> error
    end
  end

  @spec discover(keyword()) :: [Executable.t()]
  def discover(opts \\ []) do
    opts
    |> Keyword.get(:paths, Vibe.Skill.script_paths())
    |> Enum.flat_map(fn dir ->
      case load_dir(dir) do
        {:ok, skills} -> skills
        {:error, _reason} -> []
      end
    end)
    |> Enum.uniq_by(&{&1.name, &1.module})
  end

  @spec apis(keyword()) :: [API.t()]
  def apis(opts \\ []) do
    opts
    |> discover()
    |> Enum.flat_map(& &1.apis)
    |> Enum.uniq_by(&{&1.alias, &1.module})
  end

  defp files(dir) do
    dir = Path.expand(dir)

    [
      Path.join(dir, "**/*.skill.exs"),
      Path.join(dir, "**/skill.exs")
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
  end

  defp skill_module?(module) do
    Code.ensure_loaded?(module) and Vibe.Skill.Script in behaviours(module)
  end

  defp behaviours(module), do: module.module_info(:attributes) |> Keyword.get(:behaviour, [])

  defp executable(module, path) do
    metadata = module.metadata()
    name = Map.fetch!(metadata, :name)

    %Executable{
      name: name,
      path: path,
      module: module,
      metadata: metadata,
      markdown: module.markdown(),
      apis: Enum.map(module.apis(), &Vibe.Plugin.API.new/1)
    }
  end
end
