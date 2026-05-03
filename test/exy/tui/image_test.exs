defmodule Exy.TUI.ImageTest do
  use ExUnit.Case, async: true

  test "detects kitty-compatible terminals" do
    assert Exy.TUI.Image.capabilities(%{"KITTY_WINDOW_ID" => "1"}).images == :kitty
    assert Exy.TUI.Image.capabilities(%{"TERM_PROGRAM" => "Ghostty"}).images == :kitty
    assert Exy.TUI.Image.capabilities(%{"ITERM_SESSION_ID" => "x"}).images == :iterm2
    assert Exy.TUI.Image.capabilities(%{"KITTY_WINDOW_ID" => "1", "TMUX" => "x"}).images == nil
  end

  test "renders kitty image sequence" do
    sequence =
      Exy.TUI.Image.kitty("abcd", columns: 2, rows: 3, image_id: 4) |> IO.iodata_to_binary()

    assert sequence == "\e_Ga=T,f=100,q=2,c=2,r=3,i=4;abcd\e\\"
  end

  test "renders image fallback" do
    image = %Exy.Model.Content.Image{
      mime_type: "image/png",
      filename: "tiny.png",
      width: 1,
      height: 2,
      data: "abc"
    }

    assert Exy.TUI.Image.fallback(image) == "[Image: tiny.png image/png 1x2]"
  end
end
