defmodule Exy.Workspace do
  @moduledoc """
  Workspace path policy for project-scoped file operations.
  """

  @type policy :: %{root: Path.t(), allow_absolute?: boolean()}

  @spec policy(keyword()) :: policy()
  def policy(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    allow_absolute? = Keyword.get(opts, :allow_absolute, false)
    %{root: root, allow_absolute?: allow_absolute?}
  end

  @spec resolve(String.t(), keyword()) :: {:ok, Path.t()} | {:error, String.t()}
  def resolve(path, opts \\ []) when is_binary(path) do
    policy = policy(opts)

    if Path.type(path) == :absolute and not policy.allow_absolute? do
      {:error, "absolute paths are not allowed outside the workspace: #{path}"}
    else
      absolute = Path.expand(path, policy.root)

      if inside?(absolute, policy.root) do
        {:ok, absolute}
      else
        {:error, "path escapes workspace #{policy.root}: #{path}"}
      end
    end
  end

  @spec relative(Path.t(), keyword()) :: Path.t()
  def relative(path, opts \\ []) do
    root = policy(opts).root
    Path.relative_to(path, root)
  end

  defp inside?(path, root) do
    path == root or String.starts_with?(path, root <> "/")
  end
end
