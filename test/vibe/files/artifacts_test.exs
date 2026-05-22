defmodule Vibe.Files.ArtifactsTest do
  use ExUnit.Case, async: true

  alias Vibe.Files.{Artifacts, ImageRef}
  alias Vibe.Image

  test "keeps small images inline" do
    image = image(data: Base.encode64("small"))

    assert {:ok, ^image} = Artifacts.maybe_store_image(image, inline_image_bytes: 100)
  end

  test "summarizes and prunes orphan artifact directories" do
    session_dir =
      Path.join(System.tmp_dir!(), "vibe-artifact-prune-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    try do
      dir = Artifacts.session_artifact_dir("orphan")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "image.png"), "12345")

      assert Artifacts.session_artifact_summary("orphan") == %{count: 1, bytes: 5}
      assert Artifacts.prune_orphans([]) == [dir]
      refute File.exists?(dir)
    after
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

      File.rm_rf(session_dir)
    end
  end

  test "stores large images as artifact refs without encoding data to JSON" do
    dir = Path.join(System.tmp_dir!(), "vibe-artifact-test-#{System.unique_integer([:positive])}")
    image = image(data: Base.encode64("large-payload"))

    handler = "artifact-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach(
      handler,
      [:vibe, :image, :artifact, :stored],
      &__MODULE__.handle_artifact_stored/4,
      parent
    )

    try do
      assert {:ok, %ImageRef{} = ref} =
               Artifacts.maybe_store_image(image,
                 inline_image_bytes: 4,
                 artifact_dir: dir
               )

      assert File.read!(ref.path) == "large-payload"
      assert ref.data == image.data

      assert_receive {:telemetry_event, [:vibe, :image, :artifact, :stored],
                      %{bytes: 5, count: 1}, %{mime_type: "image/png"}}

      encoded = ref |> Vibe.Tool.Transport.JSON.value() |> Jason.encode!()
      assert encoded =~ ref.path
      refute encoded =~ image.data
    after
      :telemetry.detach(handler)
      File.rm_rf(dir)
    end
  end

  def handle_artifact_stored(event, measurements, metadata, parent) do
    send(parent, {:telemetry_event, event, measurements, metadata})
  end

  defp image(opts) do
    %Image{
      data: Keyword.fetch!(opts, :data),
      mime_type: "image/png",
      filename: "sample.png",
      size_bytes: 5,
      width: 1,
      height: 1,
      original_width: 1,
      original_height: 1
    }
  end
end
