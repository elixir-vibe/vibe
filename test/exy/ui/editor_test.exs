defmodule Exy.UI.EditorTest do
  use ExUnit.Case, async: true

  alias Exy.UI.Editor

  test "edits multiline text and submits" do
    editor = Editor.new()
    {editor, []} = Editor.handle_key(editor, {:insert, "hello"})
    {editor, []} = Editor.handle_key(editor, :enter)
    {editor, []} = Editor.handle_key(editor, {:paste, "world\r\n!"})
    {editor, [{:submit, text}]} = Editor.handle_key(editor, :submit)

    assert text == "hello\nworld\n!"
    assert editor.text == ""
    assert editor.history == [text]
  end

  test "moves cursor and deletes" do
    editor = Editor.new(text: "abc", cursor: 3)
    {editor, []} = Editor.handle_key(editor, :left)
    {editor, []} = Editor.handle_key(editor, :backspace)

    assert editor.text == "ac"
    assert editor.cursor == 1
  end
end
