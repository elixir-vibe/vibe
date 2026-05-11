defmodule Vibe.TUI.WidgetsTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI

  @sample_token_count 1_200

  alias Vibe.TUI.{Theme, Widget, Width}

  test "renders section, status, model info, dialog, and diff widgets" do
    nodes = [
      TUI.section("Tools", [TUI.text("eval")]),
      TUI.status(title: "Expert", description: "ready", color: :success),
      TUI.model_info(
        model: "gpt-5.5",
        provider: "openai_codex",
        usage: %{total_tokens: @sample_token_count}
      ),
      TUI.dialog("Resume", [TUI.text("session")]),
      TUI.diff(lines: [{:del, "old"}, {:add, "new"}])
    ]

    plain =
      nodes
      |> Enum.flat_map(&Widget.render(&1, 80, Theme.default()))
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "Tools"
    assert plain =~ "Expert ready"
    assert plain =~ "gpt-5.5 via openai_codex"
    assert plain =~ "Resume"
    assert plain =~ "-old"
    assert plain =~ "+new"
  end

  test "confirmation widget renders title message and choices" do
    lines =
      TUI.confirmation(
        title: "Clear session?",
        message: "This will delete all messages in the current session.",
        items: ["Yes", "No"],
        selected: 0
      )
      |> Widget.render(60, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(lines, &String.contains?(&1, "Clear session?"))
    assert Enum.any?(lines, &String.contains?(&1, "This will delete all messages"))
    assert Enum.any?(lines, &String.contains?(&1, "→ Yes"))
    assert Enum.any?(lines, &String.contains?(&1, "  No"))
  end

  test "dialog keeps right border on every framed row" do
    lines =
      TUI.dialog("Resume", [TUI.text("session")], hint: "enter opens")
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.all?(lines, &(String.length(&1) == 40))

    assert Enum.all?(
             lines,
             &(String.ends_with?(&1, "│") or String.ends_with?(&1, "╮") or
                 String.ends_with?(&1, "╯"))
           )
  end

  test "message widgets use content blocks without speaker labels" do
    user =
      TUI.message(%{role: :user, text: "hello"})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assistant =
      TUI.message(%{role: :assistant, text: "hi"})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    thinking =
      TUI.message(%{role: :assistant, text: ""})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert user == [
             String.duplicate(" ", 40),
             "  hello" <> String.duplicate(" ", 33),
             String.duplicate(" ", 40)
           ]

    user_with_image =
      TUI.message(%{role: :user, text: "hello", image_count: 1})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(user_with_image, &String.contains?(&1, "[1 image attached]"))

    user_with_url =
      TUI.message(%{role: :user, text: "https://example.com/path"})
      |> Widget.render(60, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert user_with_url =~ "https://example.com/path"
    refute user_with_url =~ "(https://example.com/path)"

    assert assistant == [
             String.duplicate(" ", 40),
             "  hi" <> String.duplicate(" ", 36),
             String.duplicate(" ", 40)
           ]

    assert thinking == ["  ✦ Thinking…"]

    refute Enum.any?(user ++ assistant ++ thinking, &String.contains?(&1, "You:"))
    refute Enum.any?(user ++ assistant ++ thinking, &String.contains?(&1, "Vibe:"))
  end

  test "inset line helper adds symmetric edge padding and fills width" do
    line = Widget.inset_line("notice", 12) |> Width.visible_text()

    assert line == " notice     "
    assert String.length(line) == 12
  end

  test "block lines helper adds vertical padding and shared background" do
    lines =
      Widget.block_lines(["! cancelled"], 16, Theme.default(), :tool_pending_bg, padding_left: 2)

    plain = Enum.map(lines, &Width.visible_text/1)

    assert plain == [
             String.duplicate(" ", 16),
             "  ! cancelled   ",
             String.duplicate(" ", 16)
           ]
  end

  test "background line helper pads and preserves parent background across nested resets" do
    line =
      Vibe.TUI.Widget.background_line(
        Theme.bold("bold"),
        12,
        Theme.default(),
        :assistant_message_bg,
        padding_left: 2
      )
      |> IO.iodata_to_binary()

    background = IO.iodata_to_binary(Theme.bg_start(Theme.default(), :assistant_message_bg))

    assert Width.visible_text(line) == "  bold" <> String.duplicate(" ", 6)
    assert line =~ background <> "  "
    assert line =~ IO.ANSI.reset() <> background
  end

  test "message background survives nested markdown ANSI resets" do
    [blank, content, _blank] =
      TUI.message(%{role: :assistant, text: "**bold** normal"})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&IO.iodata_to_binary/1)

    background = IO.iodata_to_binary(Theme.bg_start(Theme.default(), :assistant_message_bg))

    assert blank =~ background
    assert content =~ background <> "  "
    assert content =~ IO.ANSI.reset() <> background
  end

  test "assistant errors are padded on an error background" do
    lines =
      TUI.message(%{role: :assistant, error: "boom"})
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert lines == [
             String.duplicate(" ", 40),
             "  × boom" <> String.duplicate(" ", 32),
             String.duplicate(" ", 40)
           ]
  end

  test "message renderer failures degrade to error blocks" do
    node = TUI.message(%{role: :assistant, text: ""})

    lines =
      %{node | props: Map.put(node.props, :loader_phase, :not_a_number)}
      |> Widget.render(60, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(lines, &String.contains?(&1, "RENDER ERROR"))
  end

  test "input widget renders prompt, value, cursor, and placeholder" do
    focused =
      TUI.input(value: "hello", cursor: 2)
      |> Widget.render(40, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    placeholder =
      TUI.input(value: "", placeholder: "Ask...", focused?: false)
      |> Widget.render(40, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert focused =~ "› hello"
    assert placeholder =~ "› Ask..."
  end

  test "notification widget uses message-like horizontal padding" do
    lines =
      TUI.notifications(items: [%{level: :warning, text: "unknown command: /"}])
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert [blank, line, blank] = lines
    assert String.trim(blank) == ""
    assert String.starts_with?(line, "  ")
    assert String.ends_with?(line, " ")
    assert String.length(line) == 40
    assert line =~ "unknown command: /"
  end

  test "autocomplete widget renders empty selectors with nil limits" do
    lines =
      TUI.autocomplete(title: "Sessions", items: [], selected: 0, limit: nil)
      |> Widget.render(50, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(lines, &String.contains?(&1, "Sessions"))
    assert Enum.any?(lines, &String.contains?(&1, "No matches"))
  end

  test "autocomplete widget renders reusable suggestions" do
    lines =
      TUI.autocomplete(
        title: "Commands",
        query: "se",
        items: [%{value: "/sessions", label: "/sessions", detail: "Browse sessions"}],
        selected: 0
      )
      |> Widget.render(50, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header_index = Enum.find_index(lines, &String.contains?(&1, "Commands"))

    assert header_index
    assert lines |> Enum.at(header_index - 1) |> String.trim() == ""
    assert lines |> Enum.at(header_index + 1) |> String.trim() == ""
    assert Enum.any?(lines, &String.contains?(&1, "/sessions"))
    assert Enum.any?(lines, &String.contains?(&1, "Browse sessions"))
  end

  test "textarea widget renders multiline prompt box" do
    lines =
      TUI.textarea(title: "Prompt", value: "hello\nworld", cursor: 2, min_rows: 3)
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert hd(lines) =~ "Prompt"
    assert Enum.any?(lines, &String.contains?(&1, "hello"))
    assert Enum.any?(lines, &String.contains?(&1, "world"))
    assert length(lines) == 5
  end

  test "textarea cursor before newline renders as a visible cell without consuming the newline" do
    lines =
      TUI.textarea(title: "Prompt", value: "hello\nworld", cursor: 5, min_rows: 3)
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(lines, &String.contains?(&1, "hello "))
    assert Enum.any?(lines, &String.contains?(&1, "world"))
  end

  test "loader widget renders Vibe's reusable waiting indicator phases" do
    plain =
      for phase <- 0..3 do
        TUI.loader(label: "Working", phase: phase)
        |> Widget.render(40, Theme.default())
        |> Enum.map(&Width.visible_text/1)
      end

    assert plain == [["  ✦ Working…"], ["  ⋰ Working…"], ["  ⋱ Working…"], ["  ✧ Working…"]]
  end

  test "layout primitives render boxes, padding, horizontal rows, spacers, and truncation" do
    lines =
      TUI.box("Layout", [
        TUI.horizontal([TUI.text("left"), TUI.text("right")]),
        TUI.spacer(),
        TUI.padding([TUI.truncate("abcdef", suffix: "…")], x: 2)
      ])
      |> Widget.render(30, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert hd(lines) =~ "Layout"
    assert Enum.any?(lines, &String.contains?(&1, "left"))
    assert Enum.any?(lines, &String.contains?(&1, "right"))
    assert Enum.any?(lines, &String.contains?(&1, "abcdef"))
  end
end
