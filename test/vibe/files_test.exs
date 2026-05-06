defmodule Vibe.FilesTest do
  use ExUnit.Case, async: true

  alias Vibe.Image
  alias Vibe.Model.Content
  alias Vibe.UI.{Event, ToolEvent}

  defmodule FakeResizeBackend do
    @behaviour Vibe.Image.Resize.Backend

    @impl true
    def available?, do: true

    @impl true
    def supports?(%Image{}), do: true

    @impl true
    def resize(%Image{} = image, _opts),
      do: {:ok, %Image{image | width: 1, height: 1, was_resized?: true}}
  end

  @tmp Path.join(System.tmp_dir!(), "vibe-file-tools-test")

  setup do
    dir = Path.join(@tmp, Integer.to_string(System.unique_integer([:positive])))
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "reads files with metadata", %{dir: dir} do
    path = Path.join(dir, "sample.ex")
    File.write!(path, "IO.puts(:ok)\n")

    assert {:ok, result} = Vibe.Files.read_file("sample.ex", root: dir)
    assert result.content == "IO.puts(:ok)\n"
    assert result.language == "elixir"
    assert result.lines == 1
  end

  test "reads image files as typed content parts", %{dir: dir} do
    png =
      <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0,
        0, 0, 0, 0, 0, 0>>

    File.write!(Path.join(dir, "tiny.png"), png)

    assert {:ok, result} = Vibe.Files.read_file("tiny.png", root: dir)
    assert result.content_type == :image
    assert result.mime_type == "image/png"
    assert result.width == 1
    assert result.height == 1
    assert [%Content.Text{}, %Content.Image{} = image] = result.parts
    assert image.data == Base.encode64(png)
  end

  test "can resize image files through configured backends", %{dir: dir} do
    png =
      <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 15, 160, 0, 0, 0, 1, 8, 6,
        0, 0, 0, 0, 0, 0, 0>>

    File.write!(Path.join(dir, "wide.png"), png)

    assert {:ok, result} =
             Vibe.Files.read_file("wide.png",
               root: dir,
               resize?: true,
               backends: [FakeResizeBackend]
             )

    assert result.width == 1
    assert result.height == 1
  end

  test "stores large image payloads as artifact refs", %{dir: dir} do
    png =
      <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0,
        0, 0, 0, 0, 0, 0>>

    artifact_dir = Path.join(dir, "artifacts")
    File.write!(Path.join(dir, "large.png"), png)

    assert {:ok, result} =
             Vibe.Files.read_file("large.png",
               root: dir,
               inline_image_bytes: 4,
               artifact_dir: artifact_dir
             )

    assert %Vibe.Files.ImageRef{} = result.image
    assert File.exists?(result.image.path)
    refute Jason.encode!(result.image) =~ result.image.data
  end

  test "preserves image content structs across session storage" do
    session_id = "image-content-roundtrip-#{System.unique_integer([:positive])}"

    output = %{
      content_type: :image,
      parts: [
        Content.text("Read image file [image/png]"),
        Content.image(
          data: "abc",
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 1
        )
      ]
    }

    Vibe.Session.Store.append_ui_events([
      {1,
       Event.new(
         :tool_finished,
         session_id,
         ToolEvent.finished(
           id: "read-image",
           name: :read,
           args: %{path: "tiny.png"},
           output: output
         )
       )}
    ])

    assert [{1, event}] = Vibe.Session.Store.ui_events(session_id)

    assert [%Content.Text{}, %Content.Image{} = image] =
             event.data.output.parts

    assert image.filename == "tiny.png"
  end

  test "writes files and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")

    assert {:ok, result} = Vibe.Files.write_file("sample.txt", "new\n", root: dir)
    assert File.read!(path) == "new\n"
    assert result.change.diff =~ "+1  new"
  end

  test "edits files with exact replacements and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "one\ntwo\nthree\n")

    assert {:ok, result} =
             Vibe.Files.edit_file("sample.txt", [%{"oldText" => "two", "newText" => "TWO"}],
               root: dir
             )

    assert File.read!(path) == "one\nTWO\nthree\n"
    assert result.replacements == 1
    assert result.change.diff =~ "-2  two"
    assert result.change.diff =~ "+2  TWO"
  end

  test "allows symlinks that resolve outside the root", %{dir: dir} do
    outside = Path.join(System.tmp_dir!(), "vibe-outside-#{System.unique_integer([:positive])}")
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "shared.txt"), "shared")
    File.ln_s!(outside, Path.join(dir, "link"))

    try do
      assert {:ok, result} = Vibe.Files.read_file("link/shared.txt", root: dir)
      assert result.content == "shared"
    after
      File.rm_rf(outside)
    end
  end

  test "allows absolute and parent-relative paths outside the root", %{dir: dir} do
    external =
      Path.join(System.tmp_dir!(), "vibe-extra-path-#{System.unique_integer([:positive])}")

    File.mkdir_p!(external)

    try do
      absolute = Path.join(external, "sample.txt")
      relative = Path.relative_to(absolute, dir)

      assert {:ok, result} = Vibe.Files.write_file(absolute, "hello", root: dir)
      assert result.path == absolute
      assert {:ok, result} = Vibe.Files.read_file(relative, root: dir)
      assert result.content == "hello"
    after
      File.rm_rf(external)
    end
  end

  test "rejects duplicate exact edit matches", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "same\nsame\n")

    assert {:error, error} =
             Vibe.Files.edit_file("sample.txt", [%{"oldText" => "same", "newText" => "other"}],
               root: dir
             )

    assert error =~ "must be unique"
  end
end
