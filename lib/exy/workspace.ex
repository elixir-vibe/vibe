defmodule Exy.Workspace do
  @moduledoc """
  Workspace path policy for project-scoped file operations.
  """

  @type policy :: %{root: Path.t(), real_root: Path.t(), allow_absolute?: boolean()}

  @spec policy(keyword()) :: policy()
  def policy(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    real_root = resolve_symlinks(root)
    allow_absolute? = Keyword.get(opts, :allow_absolute, false)
    %{root: root, real_root: real_root, allow_absolute?: allow_absolute?}
  end

  @spec resolve(String.t(), keyword()) :: {:ok, Path.t()} | {:error, String.t()}
  def resolve(path, opts \\ []) when is_binary(path) do
    policy = policy(opts)

    if Path.type(path) == :absolute and not policy.allow_absolute? do
      {:error, "absolute paths are not allowed outside the workspace: #{path}"}
    else
      absolute = Path.expand(path, policy.root)

      with :ok <- ensure_lexically_inside(absolute, policy.root, path),
           :ok <- ensure_physically_inside(absolute, policy.real_root, path) do
        {:ok, absolute}
      end
    end
  end

  @spec relative(Path.t(), keyword()) :: Path.t()
  def relative(path, opts \\ []) do
    root = policy(opts).root
    Path.relative_to(path, root)
  end

  defp ensure_lexically_inside(path, root, original) do
    if inside?(path, root), do: :ok, else: {:error, "path escapes workspace #{root}: #{original}"}
  end

  defp ensure_physically_inside(path, real_root, original) do
    real_path = resolve_symlinks(path)

    if inside?(real_path, real_root) do
      :ok
    else
      {:error, "path resolves outside workspace #{real_root}: #{original}"}
    end
  end

  defp resolve_symlinks(path) do
    path
    |> Path.expand()
    |> Path.split()
    |> resolve_parts()
  end

  defp resolve_parts([root | parts]) when root in ["/", "\\"] do
    Enum.reduce(parts, root, &resolve_part/2)
  end

  defp resolve_parts(parts), do: Enum.reduce(parts, "", &resolve_part/2)

  defp resolve_part(part, acc) do
    candidate = Path.join(acc, part)

    case :file.read_link(to_charlist(candidate)) do
      {:ok, target} ->
        target = List.to_string(target)
        if Path.type(target) == :absolute, do: target, else: Path.expand(target, acc)

      _other ->
        candidate
    end
  end

  defp inside?(path, root) do
    path == root or String.starts_with?(path, root <> "/")
  end
end
