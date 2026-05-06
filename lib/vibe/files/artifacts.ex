defmodule Vibe.Files.Artifacts do
  @moduledoc "Stores large tool artifacts outside inline session JSON payloads."

  alias Vibe.Files.ImageRef
  alias Vibe.Image
  alias Vibe.Paths

  @default_inline_image_bytes 1_000_000

  @spec maybe_store_image(Image.t(), keyword()) ::
          {:ok, Image.t() | ImageRef.t()} | {:error, term()}
  def maybe_store_image(%Image{} = image, opts \\ []) do
    limit = Keyword.get(opts, :inline_image_bytes, default_inline_image_bytes())

    if byte_size(image.data) <= limit do
      {:ok, image}
    else
      store_image(image, opts)
    end
  end

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

  @spec store_image(Image.t(), keyword()) :: {:ok, ImageRef.t()} | {:error, term()}
  def store_image(%Image{} = image, opts \\ []) do
    case Base.decode64(image.data) do
      {:ok, binary} ->
        dir = image_dir(opts)
        path = Path.join(dir, artifact_filename(image))

        File.mkdir_p!(dir)
        File.write!(path, binary)
        emit_image_artifact_event(image, path)

        {:ok,
         %ImageRef{
           path: path,
           mime_type: image.mime_type,
           filename: image.filename,
           size_bytes: image.size_bytes,
           width: image.width,
           height: image.height,
           data: image.data
         }}

      :error ->
        {:error, :invalid_base64_image_data}
    end
  end

  @spec prune_orphans([String.t()] | nil) :: [Path.t()]
  def prune_orphans(live_session_ids \\ nil) do
    known = MapSet.new(live_session_ids || stored_session_ids())

    Paths.sessions_dir()
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.reject(&MapSet.member?(known, Path.basename(&1)))
    |> Enum.map(&Path.join(&1, "artifacts"))
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(fn dir ->
      File.rm_rf!(dir)
      dir
    end)
  end

  @spec session_artifact_summary(String.t()) :: %{
          count: non_neg_integer(),
          bytes: non_neg_integer()
        }
  def session_artifact_summary(session_id) when is_binary(session_id) do
    session_id
    |> session_artifact_dir()
    |> artifact_summary()
  end

  defp artifact_summary(dir) do
    dir
    |> all_files()
    |> Enum.reduce(%{count: 0, bytes: 0}, fn path, acc ->
      size =
        case File.stat(path) do
          {:ok, stat} -> stat.size
          _ -> 0
        end

      %{count: acc.count + 1, bytes: acc.bytes + size}
    end)
  end

  defp all_files(dir) do
    if File.dir?(dir),
      do: dir |> Path.join("**/*") |> Path.wildcard() |> Enum.filter(&File.regular?/1),
      else: []
  end

  defp stored_session_ids do
    Vibe.Session.Store.list()
    |> Enum.map(& &1.id)
  end

  @spec default_inline_image_bytes() :: pos_integer()
  def default_inline_image_bytes do
    Application.get_env(:vibe, :inline_image_bytes, @default_inline_image_bytes)
  end

  defp emit_image_artifact_event(image, path) do
    Vibe.Telemetry.execute(
      [:vibe, :image, :artifact, :stored],
      %{bytes: image.size_bytes || 0, count: 1},
      %{
        mime_type: image.mime_type,
        filename: image.filename,
        width: image.width,
        height: image.height,
        resized?: image.was_resized?,
        artifact_path: path
      }
    )
  rescue
    _exception -> :ok
  end

  defp image_dir(opts) do
    cond do
      dir = Keyword.get(opts, :artifact_dir) ->
        dir

      session_id = Keyword.get(opts, :session_id) ->
        Path.join([session_artifact_dir(session_id), "images"])

      true ->
        Path.join([Paths.sessions_dir(), "artifacts", "images"])
    end
  end

  defp artifact_filename(%Image{} = image) do
    extension = extension(image.mime_type)
    basename = image.filename || "image#{extension}"

    digest =
      :crypto.hash(:sha256, image.data) |> Base.url_encode64(padding: false) |> binary_part(0, 16)

    root = basename |> Path.basename() |> Path.rootname() |> safe_name()
    "#{root}-#{digest}#{extension}"
  end

  defp safe_name(name) do
    name
    |> String.replace(~r/[^A-Za-z0-9._-]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "image"
      safe -> safe
    end
  end

  defp extension("image/jpeg"), do: ".jpg"
  defp extension("image/png"), do: ".png"
  defp extension("image/gif"), do: ".gif"
  defp extension("image/webp"), do: ".webp"
  defp extension(_mime_type), do: ".img"
end
