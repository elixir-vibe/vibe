defmodule Vibe.Files.ArtifactPath do
  @moduledoc false

  alias Vibe.Files.ImageRef
  alias Vibe.Paths

  @spec session_artifact_dir(String.t()) :: Path.t()
  def session_artifact_dir(session_id) when is_binary(session_id),
    do: Path.join([Paths.sessions_dir(), session_id, "artifacts"])

  @spec resolve_session_artifact(String.t(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def resolve_session_artifact(session_id, relative_path)
      when is_binary(session_id) and is_binary(relative_path) do
    root = session_artifact_dir(session_id) |> Path.expand()
    path = Path.expand(Path.join(root, relative_path))

    if path == root or String.starts_with?(path, root <> "/") do
      {:ok, path}
    else
      {:error, :invalid_artifact_path}
    end
  end

  @spec public_path(ImageRef.t()) :: String.t() | nil
  def public_path(%ImageRef{path: path}) when is_binary(path) do
    sessions_dir = Paths.sessions_dir() |> Path.expand()
    expanded = Path.expand(path)

    with true <- String.starts_with?(expanded, sessions_dir <> "/"),
         relative <- Path.relative_to(expanded, sessions_dir),
         [session_id, "artifacts" | artifact_parts] <- Path.split(relative) do
      "/sessions/#{URI.encode(session_id)}/artifacts/#{Enum.map_join(artifact_parts, "/", &URI.encode/1)}"
    else
      _ -> nil
    end
  end

  def public_path(_ref), do: nil
end
