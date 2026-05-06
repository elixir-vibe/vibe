defmodule Vibe.UI.EditorTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.Editor

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

  test "moves vertically in multiline text" do
    editor = Editor.new(text: "one\ntwo words\nthree", cursor: 10)
    assert Editor.line_column(editor) == {1, 6}

    {editor, []} = Editor.handle_key(editor, :up)
    assert Editor.line_column(editor) == {0, 3}

    {editor, []} = Editor.handle_key(editor, :down)
    assert Editor.line_column(editor) == {1, 3}
  end

  test "moves by words" do
    editor = Editor.new(text: "hello world", cursor: 11)
    {editor, []} = Editor.handle_key(editor, :word_left)
    assert editor.cursor == 6

    {editor, []} = Editor.handle_key(editor, :word_right)
    assert editor.cursor == 11
  end

  test "deletes word before cursor" do
    editor = Editor.new(text: "hello brave world", cursor: 17)
    {editor, []} = Editor.handle_key(editor, :delete_word_left)

    assert editor.text == "hello brave "
    assert editor.cursor == 12

    editor = Editor.new(text: "hello brave   ", cursor: 14)
    {editor, []} = Editor.handle_key(editor, :delete_word_left)

    assert editor.text == "hello "
    assert editor.cursor == 6
  end

  test "submits slash commands separately" do
    editor = Editor.new(text: "/model openai_codex:gpt-5.5", cursor: 27)
    {_editor, [{:slash_command, command, args}]} = Editor.handle_key(editor, :submit)

    assert command == "model"
    assert args == "openai_codex:gpt-5.5"
  end
end
