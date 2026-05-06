defmodule Vibe.Workspace do
  @moduledoc """
  Workspace path helpers for file operations.

  Vibe currently follows Pi-style local-agent semantics: paths are resolved from the
  current workspace, but absolute and parent-relative paths are allowed. A stricter
  multi-root permission model can be added later when eval and command execution
  can be governed by the same policy.
  """

  @type policy :: %{root: Path.t(), real_root: Path.t(), allow_absolute?: boolean()}

  @spec policy(keyword()) :: policy()
  def policy(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    %{root: root, real_root: resolve_symlinks(root), allow_absolute?: true}
  end

  @spec resolve(String.t(), keyword()) :: {:ok, Path.t()} | {:error, String.t()}
  def resolve(path, opts \\ []) when is_binary(path) do
    {:ok, Path.expand(path, policy(opts).root)}
  end

  @spec relative(Path.t(), keyword()) :: Path.t()
  def relative(path, opts \\ []) do
    root = policy(opts).root
    Path.relative_to(path, root)
  end

  @spec resolve_symlinks(Path.t()) :: Path.t()
  def resolve_symlinks(path) do
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
end
