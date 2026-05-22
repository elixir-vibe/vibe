defmodule Vibe.Terminal.ImageTest do
  use ExUnit.Case, async: false

  alias Vibe.Model.Content
  alias Vibe.Terminal.{Image, Theme}
  alias Vibe.TUI.Widgets.Image, as: ImageWidget

  test "detects kitty-compatible terminals" do
    assert Image.capabilities(%{"KITTY_WINDOW_ID" => "1"}).images == :kitty
    assert Image.capabilities(%{"TERM_PROGRAM" => "Ghostty"}).images == :kitty
    assert Image.capabilities(%{"ITERM_SESSION_ID" => "x"}).images == :iterm2
    assert Image.capabilities(%{"KITTY_WINDOW_ID" => "1", "TMUX" => "x"}).images == nil
  end

  test "renders kitty image sequence" do
    sequence =
      Image.kitty("abcd", columns: 2, rows: 3, image_id: 4) |> IO.iodata_to_binary()

    assert sequence == "\e_Ga=T,f=100,q=2,c=2,r=3,i=4;abcd\e\\"
  end

  test "calculates terminal rows from image aspect ratio" do
    assert Image.rows(100, 100, 10, cell_width_px: 10, cell_height_px: 20) == 5
    assert Image.rows(100, 200, 10, cell_width_px: 10, cell_height_px: 20) == 10
    assert Image.rows(nil, nil, 10) == 4
  end

  test "widget fallback occupies one padded text row" do
    with_env(
      %{
        "TERM_PROGRAM" => "vscode",
        "TERM" => "xterm-256color",
        "KITTY_WINDOW_ID" => nil,
        "GHOSTTY_RESOURCES_DIR" => nil,
        "WEZTERM_PANE" => nil,
        "ITERM_SESSION_ID" => nil
      },
      fn ->
        image = %Content.Image{
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 2,
          data: "abc"
        }

        [line] = ImageWidget.new(image) |> ImageWidget.render(40, Theme.default())

        assert IO.iodata_to_binary(line) =~ "[Image: tiny.png image/png 1x2]"
      end
    )
  end

  test "widget kitty rendering reserves continuation rows" do
    with_env(%{"TERM_PROGRAM" => "Ghostty", "TMUX" => nil}, fn ->
      image = %Content.Image{
        mime_type: "image/png",
        filename: "wide.png",
        width: 100,
        height: 100,
        data: "abc"
      }

      lines = ImageWidget.new(image) |> ImageWidget.render(10, Theme.default())

      assert length(lines) == Image.rows(100, 100, 10)
      assert Image.image_line?(IO.iodata_to_binary(hd(lines)))
      assert tl(lines) == List.duplicate("", length(lines) - 1)
    end)
  end

  defp with_env(env, fun) do
    previous = Map.new(env, fn {key, _value} -> {key, System.get_env(key)} end)

    try do
      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end

  test "renders image fallback" do
    image = %Content.Image{
      mime_type: "image/png",
      filename: "tiny.png",
      width: 1,
      height: 2,
      data: "abc"
    }

    assert Image.fallback(image) == "[Image: tiny.png image/png 1x2]"
  end
end
