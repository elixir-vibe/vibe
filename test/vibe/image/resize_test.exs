defmodule Vibe.Image.ResizeTest do
  use ExUnit.Case, async: true

  alias Vibe.Image
  alias Vibe.Image.Resize

  defmodule FakeBackend do
    @behaviour Vibe.Image.Resize.Backend

    @impl true
    def available?, do: true

    @impl true
    def supports?(%Image{}), do: true

    @impl true
    def resize(%Image{} = image, _opts) do
      {:ok, %Image{image | width: 100, height: 50, size_bytes: 10, was_resized?: true}}
    end
  end

  defmodule UnavailableBackend do
    @behaviour Vibe.Image.Resize.Backend

    @impl true
    def available?, do: false

    @impl true
    def supports?(%Image{}), do: true

    @impl true
    def resize(_image, _opts), do: flunk("unavailable backend should not be called")
  end

  test "does not call a backend when image already fits limits" do
    image = image(width: 10, height: 10, size_bytes: 3)

    assert {:ok, ^image} = Resize.resize(image, backends: [FakeBackend])
  end

  test "uses first available supporting backend when resize is needed" do
    image = image(width: 4_000, height: 1_000, size_bytes: 100)

    assert {:ok, resized} = Resize.resize(image, backends: [UnavailableBackend, FakeBackend])
    assert resized.width == 100
    assert resized.height == 50
    assert resized.was_resized?
  end

  test "reports when no backend can resize" do
    image = image(width: 4_000, height: 1_000, size_bytes: 100)

    assert {:error, :no_available_image_resize_backend} =
             Resize.resize(image, backends: [UnavailableBackend])
  end

  defp image(attrs) do
    %Image{
      data: Base.encode64("png"),
      mime_type: "image/png",
      filename: "tiny.png",
      size_bytes: Keyword.fetch!(attrs, :size_bytes),
      width: Keyword.fetch!(attrs, :width),
      height: Keyword.fetch!(attrs, :height),
      original_width: Keyword.fetch!(attrs, :width),
      original_height: Keyword.fetch!(attrs, :height)
    }
  end
end
