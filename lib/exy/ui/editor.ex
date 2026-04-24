defmodule Exy.UI.Editor do
  @moduledoc """
  Pure multiline editor model shared by terminal and future LiveView adapters.
  """

  defstruct text: "",
            cursor: 0,
            history: [],
            history_index: nil,
            completions: [],
            completion_index: 0,
            clipboard: nil

  @type key ::
          :left
          | :right
          | :up
          | :down
          | :home
          | :end
          | :backspace
          | :delete
          | :enter
          | :submit
          | :cancel
          | :tab
          | {:insert, String.t()}
          | {:paste, String.t()}
          | {:complete, [String.t()]}
          | :external_editor
          | {:external_result, String.t()}

  @type command :: {:submit, String.t()} | :cancel | {:external_editor, String.t()}
  @type t :: %__MODULE__{}

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      text: Keyword.get(opts, :text, ""),
      cursor: Keyword.get(opts, :cursor, 0),
      history: Keyword.get(opts, :history, [])
    }
    |> clamp_cursor()
  end

  @spec handle_key(t(), key()) :: {t(), [command()]}
  def handle_key(%__MODULE__{} = editor, {:insert, text}) when is_binary(text) do
    {insert(editor, text), []}
  end

  def handle_key(%__MODULE__{} = editor, {:paste, text}) when is_binary(text) do
    {insert(editor, normalize_paste(text)), []}
  end

  def handle_key(%__MODULE__{} = editor, {:complete, items}) when is_list(items) do
    {%{editor | completions: items, completion_index: 0}, []}
  end

  def handle_key(%__MODULE__{} = editor, {:external_result, text}) when is_binary(text) do
    {%{editor | text: text, cursor: String.length(text)}, []}
  end

  def handle_key(%__MODULE__{} = editor, :left),
    do: {%{editor | cursor: max(editor.cursor - 1, 0)}, []}

  def handle_key(%__MODULE__{} = editor, :right),
    do: {%{editor | cursor: min(editor.cursor + 1, String.length(editor.text))}, []}

  def handle_key(%__MODULE__{} = editor, :home),
    do: {%{editor | cursor: line_start(editor.text, editor.cursor)}, []}

  def handle_key(%__MODULE__{} = editor, :end),
    do: {%{editor | cursor: line_end(editor.text, editor.cursor)}, []}

  def handle_key(%__MODULE__{} = editor, :enter), do: {insert(editor, "\n"), []}
  def handle_key(%__MODULE__{} = editor, :cancel), do: {editor, [:cancel]}

  def handle_key(%__MODULE__{} = editor, :external_editor),
    do: {editor, [{:external_editor, editor.text}]}

  def handle_key(%__MODULE__{} = editor, :submit) do
    text = String.trim(editor.text)

    if text == "" do
      {editor, []}
    else
      history = [text | Enum.reject(editor.history, &(&1 == text))]
      {%{editor | text: "", cursor: 0, history: history, history_index: nil}, [{:submit, text}]}
    end
  end

  def handle_key(%__MODULE__{} = editor, :backspace) do
    if editor.cursor == 0 do
      {editor, []}
    else
      {left, right} = String.split_at(editor.text, editor.cursor)
      left = left |> String.graphemes() |> Enum.drop(-1) |> Enum.join()
      {%{editor | text: left <> right, cursor: editor.cursor - 1}, []}
    end
  end

  def handle_key(%__MODULE__{} = editor, :delete) do
    {_deleted, updated} = delete_at(editor.text, editor.cursor)
    {%{editor | text: updated}, []}
  end

  def handle_key(%__MODULE__{} = editor, :up), do: history(editor, 1)
  def handle_key(%__MODULE__{} = editor, :down), do: history(editor, -1)

  def handle_key(%__MODULE__{completions: []} = editor, :tab), do: {editor, []}

  def handle_key(%__MODULE__{} = editor, :tab) do
    completion = Enum.at(editor.completions, editor.completion_index, "")
    next_index = rem(editor.completion_index + 1, max(length(editor.completions), 1))
    {%{insert(editor, completion) | completion_index: next_index}, []}
  end

  def handle_key(%__MODULE__{} = editor, _key), do: {editor, []}

  @spec lines(t()) :: [String.t()]
  def lines(%__MODULE__{text: text}), do: String.split(text, "\n")

  defp insert(editor, text) do
    {left, right} = String.split_at(editor.text, editor.cursor)
    %{editor | text: left <> text <> right, cursor: editor.cursor + String.length(text)}
  end

  defp history(%__MODULE__{history: []} = editor, _direction), do: {editor, []}

  defp history(editor, direction) do
    current = editor.history_index || -1
    next = (current + direction) |> max(0) |> min(length(editor.history) - 1)
    text = Enum.at(editor.history, next, editor.text)
    {%{editor | text: text, cursor: String.length(text), history_index: next}, []}
  end

  defp delete_at(text, cursor) do
    {left, right} = String.split_at(text, cursor)

    case String.next_grapheme(right) do
      nil -> {nil, text}
      {deleted, rest} -> {deleted, left <> rest}
    end
  end

  defp line_start(text, cursor) do
    text
    |> String.slice(0, cursor)
    |> String.split("\n")
    |> List.last()
    |> String.length()
    |> then(&(cursor - &1))
  end

  defp line_end(text, cursor) do
    text
    |> String.slice(cursor..-1//1)
    |> String.split("\n", parts: 2)
    |> hd()
    |> String.length()
    |> Kernel.+(cursor)
  end

  defp normalize_paste(text), do: String.replace(text, "\r\n", "\n")

  defp clamp_cursor(editor),
    do: %{editor | cursor: editor.cursor |> max(0) |> min(String.length(editor.text))}
end
