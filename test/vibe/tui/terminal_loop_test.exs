defmodule Vibe.TUI.TerminalLoopTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{TerminalLoop, Width}

  @long_prompt_sleep_ms 5_000
  @render_wait_timeout_ms 1_000
  @long_command_timeout_ms 120_000

  test "decodes input into app/editor and renders textarea" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)

    assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :h, utf8: "h"})
    assert :ok = TerminalLoop.input(loop, "ello")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "hello"))
  end

  test "renders model selector after slash command submit" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 20)

    assert :ok = TerminalLoop.input(loop, "/model")
    assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    plain =
      wait_until_render(loop, &Enum.any?(&1, fn line -> String.contains?(line, "Model") end))

    assert Enum.any?(plain, &String.contains?(&1, "Model"))
    assert Enum.any?(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    assert selector_rendered_once?(plain, "Model")
    assert picker_has_margin_before_footer?(plain)
    refute autocomplete_artifact?(plain)
  end

  test "slash commands still render after switching sessions" do
    source_id = "switch-source-#{System.unique_integer([:positive])}"
    target_id = "switch-target-#{System.unique_integer([:positive])}"

    {:ok, source} =
      Vibe.Session.start_link(
        session_id: source_id,
        persist?: false,
        name: Vibe.Session.Listing.via(source_id)
      )

    {:ok, target} =
      Vibe.Session.start_link(
        session_id: target_id,
        persist?: false,
        name: Vibe.Session.Listing.via(target_id)
      )

    :ok =
      Vibe.Session.emit_transient_event(
        target,
        Vibe.UI.Event.new(:assistant_message_added, target_id, %{text: "target session"})
      )

    {:ok, loop} =
      TerminalLoop.start_link(output: false, width: 100, height: 24, session_server: source)

    :ok =
      Vibe.Session.emit_transient_event(
        source,
        Vibe.UI.Event.new(:session_selected, source_id, %{session_id: target_id})
      )

    Process.sleep(50)
    :ok = TerminalLoop.input(loop, "/model")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    plain = wait_until_render(loop, &selector_rendered_once?(&1, "Model"))

    assert Enum.any?(plain, &String.contains?(&1, "target session"))
    assert selector_rendered_once?(plain, "Model")
    assert Enum.any?(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
  end

  test "renders sessions selector without stale autocomplete overlay" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 120, height: 30)

    assert :ok = TerminalLoop.input(loop, "/sessions")
    assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    plain =
      wait_until_render(loop, &Enum.any?(&1, fn line -> String.contains?(line, "Sessions") end))

    assert selector_rendered_once?(plain, "Sessions")

    if Enum.any?(plain, &String.contains?(&1, "No matches")) do
      assert picker_panel_shape(plain, "Sessions") == {:blank, :title, :blank, :other}
    else
      assert Enum.any?(plain, &String.contains?(&1, "msg"))
      assert picker_panel_shape(plain, "Sessions") == {:blank, :title, :blank, :selected_row}
      assert selected_row_prefix(plain, "Sessions") == "  › "
    end

    assert picker_has_margin_before_footer?(plain)
    refute autocomplete_artifact?(plain)
    refute Enum.any?(plain, &String.contains?(&1, "Commands"))
  end

  test "command autocomplete, model selector, and sessions selector share panel chrome" do
    commands_plain = picker_plain("/")
    model_plain = picker_plain("/model")
    sessions_plain = picker_plain("/sessions")

    assert picker_panel_shape(commands_plain, "Commands") ==
             picker_panel_shape(model_plain, "Model")

    assert picker_panel_shape(commands_plain, "Commands") ==
             picker_panel_shape(sessions_plain, "Sessions")

    assert selected_row_prefix(commands_plain, "Commands") ==
             selected_row_prefix(model_plain, "Model")

    assert selected_row_prefix(commands_plain, "Commands") ==
             selected_row_prefix(sessions_plain, "Sessions")

    assert picker_has_margin_before_footer?(commands_plain)
    assert picker_has_margin_before_footer?(model_plain)
    assert picker_has_margin_before_footer?(sessions_plain)
    assert picker_top_margin_visible?(commands_plain, "Commands")
    assert picker_top_margin_visible?(model_plain, "Model")
    assert picker_top_margin_visible?(sessions_plain, "Sessions")
  end

  test "command autocomplete keeps the selected row visible while cycling" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 120, height: 30)
    assert :ok = TerminalLoop.input(loop, "/")

    commands = Vibe.UI.SlashCommands.autocomplete("/").items |> Enum.map(& &1.value)
    expected = Vibe.Support.Lists.append(commands, hd(commands))

    for {command, step} <- Enum.with_index(expected) do
      if step > 0 do
        assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :arrow_down})
      end

      plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
      assert selected_picker_row(plain) =~ command
    end
  end

  test "selector confirmation stays responsive with expanded tool output" do
    session_id = "selector-expanded-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(output: false, width: 100, height: 24, session_server: session)

    content = Enum.map_join(1..800, "\n", &"def item_#{&1}, do: #{&1}")

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(
          :tool_started,
          session_id,
          Vibe.UI.ToolEvent.started(id: "read-1", name: :read, args: %{path: "large.ex"})
        )
      )

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(
          :tool_finished,
          session_id,
          Vibe.UI.ToolEvent.finished(
            id: "read-1",
            name: :read,
            args: %{path: "large.ex"},
            output: {:ok, %{path: "large.ex", content: content, language: "elixir"}, []}
          )
        )
      )

    Process.sleep(50)
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :o, mods: [:ctrl]})
    _expanded = TerminalLoop.render(loop)
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :l, mods: [:ctrl]})

    {elapsed_us, :ok} =
      :timer.tc(fn -> TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter}) end)

    assert elapsed_us < 50_000
  end

  test "editor-only input reuses cached body blocks" do
    session_id = "editor-cache-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(output: false, width: 100, height: 24, session_server: session)

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(
          :tool_finished,
          session_id,
          Vibe.UI.ToolEvent.finished(
            id: "read-1",
            name: :read,
            args: %{path: "large.ex"},
            output: {:ok, read_output("large.ex", 300), []}
          )
        )
      )

    first = TerminalLoop.render_frame(loop)
    :ok = TerminalLoop.input(loop, "x")
    second = TerminalLoop.render_frame(loop)

    assert second.stats.hits > first.stats.hits
  end

  test "ctrl-w deletes the word before the cursor" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)

    assert :ok = TerminalLoop.input(loop, "hello brave world")
    assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :w, mods: [:ctrl]})

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "hello brave"))
    refute Enum.any?(plain, &String.contains?(&1, "world"))
  end

  test "preserves eval inspect highlighting through session view model" do
    session_id = "terminal-color-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(output: false, width: 120, height: 30, session_server: session)

    code =
      ~S|%{answer: 42, elixir: System.version(), example_struct: %URI{scheme: "https", host: "example.com"}}|

    assert {:ok, action_result} = Vibe.Actions.Eval.run(%{code: code}, %{session_id: session_id})

    assert :ok =
             Vibe.Session.emit_transient_event(
               session,
               Vibe.UI.Event.new(
                 :tool_started,
                 session_id,
                 Vibe.UI.ToolEvent.started(id: "eval-1", name: :eval, args: %{code: code})
               )
             )

    assert :ok =
             Vibe.Session.emit_transient_event(
               session,
               Vibe.UI.Event.new(
                 :tool_finished,
                 session_id,
                 Vibe.UI.ToolEvent.finished(
                   id: "eval-1",
                   name: :eval,
                   args: %{code: code},
                   output: {:ok, action_result, []}
                 )
               )
             )

    Process.sleep(50)

    rendered = loop |> TerminalLoop.render() |> IO.iodata_to_binary()

    assert rendered =~ "answer"
    assert rendered =~ "38;2;97;175;239"
    assert rendered =~ "38;2;152;195;121"
  end

  test "keeps prompt visible after a tool-heavy phoenix session replay" do
    session_id = "phoenix-replay-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 160,
        height: 24,
        session_server: session,
        event_target: self()
      )

    assert {:ok, terminal} = Ghostty.Terminal.start_link(cols: 160, rows: 24)

    painter =
      Enum.reduce(
        replayed_phoenix_events(session_id),
        Vibe.TUI.TerminalPainter.new(160, 24),
        fn event, painter ->
          :ok = Vibe.Session.emit_transient_event(session, event)
          {screen, painter} = paint_screen(loop, terminal, painter)

          assert screen =~ "Prompt"
          refute last_non_blank_line(screen) =~ "openai_codex:gpt-5.5"

          painter
        end
      )

    :ok = TerminalLoop.input(loop, "keep typing responsive")
    {screen, _painter} = paint_screen(loop, terminal, painter)

    assert screen =~ "openai_codex:gpt-5.5"
    assert screen =~ "Prompt"
    assert screen =~ "keep typing responsive"
    refute last_non_blank_line(screen) =~ "openai_codex:gpt-5.5"
  end

  test "keeps editor visible in a bounded viewport" do
    ask = fn text, _opts -> {:ok, Enum.map_join(1..20, "\n", &"line #{&1}: #{text}")} end
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12, ask_fun: ask)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    Process.sleep(50)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    footer_index = Enum.find_index(plain, &String.contains?(&1, "~/Development/"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))

    assert length(plain) <= 12
    assert footer_index
    assert prompt_index == footer_index + 1
  end

  test "repaints immediately for background UI updates" do
    session_id = "background-ui-#{System.unique_integer([:positive])}"

    {:ok, output} = StringIO.open("")

    {:ok, _loop} =
      TerminalLoop.start_link(output: output, width: 60, height: 12, session_id: session_id)

    assert :ok = Vibe.Plugin.UI.set_status(session_id, :indexer, "indexing")
    assert {:ok, contents} = wait_for_output(output, "indexing")
    assert contents =~ "indexing"
  end

  test "output paint uses terminal line diff after first frame" do
    session_id = "diff-output-#{System.unique_integer([:positive])}"
    {:ok, output} = StringIO.open("")

    {:ok, _loop} =
      TerminalLoop.start_link(output: output, width: 60, height: 12, session_id: session_id)

    assert :ok = Vibe.Plugin.UI.set_status(session_id, :indexer, "indexing")
    assert {:ok, first} = wait_for_output(output, "indexing")
    refute first =~ IO.ANSI.clear()

    assert :ok = Vibe.Plugin.UI.set_status(session_id, :indexer, "ready")
    assert {:ok, second} = wait_for_output(output, "ready")

    assert count_occurrences(second, IO.ANSI.clear()) == 0
  end

  test "expanded eval output remains reachable through native scrollback" do
    session_id = "eval-scrollback-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 80,
        height: 12,
        session_server: session,
        event_target: self()
      )

    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 80, rows: 12, max_scrollback: 1_000)

    output = Enum.map_join(1..80, "\n", &"line #{&1}")

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        tool_started(session_id, "eval-scroll", :eval, %{code: "many()"})
      )

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(
          :tool_finished,
          session_id,
          Vibe.UI.ToolEvent.finished(
            id: "eval-scroll",
            name: :eval,
            args: %{code: "many()"},
            output:
              {:ok,
               %{
                 output: output,
                 output_format: :text,
                 output_parts: [],
                 output_truncation: :head
               }, []}
          )
        )
      )

    Process.sleep(50)
    painter = Vibe.TUI.TerminalPainter.new(80, 12)
    {collapsed, painter} = paint_screen(loop, terminal, painter)

    assert collapsed =~ "line 1"
    refute collapsed =~ "line 80"

    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :o, mods: [:ctrl]})
    Process.sleep(50)
    {expanded, _painter} = paint_screen(loop, terminal, painter)

    assert expanded =~ "line 80"
    assert %{total: total, len: 12} = Ghostty.Terminal.scrollbar(terminal)
    assert total >= 80

    :ok = Ghostty.Terminal.scroll(terminal, -1_000)
    {:ok, scrollback} = Ghostty.Terminal.snapshot(terminal, :plain)

    assert scrollback =~ "line 1"
    assert scrollback =~ "line 80"
  end

  test "streaming updates do not append repeated live footers into scrollback" do
    session_id = "stream-scrollback-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 80,
        height: 12,
        session_server: session,
        event_target: self()
      )

    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 80, rows: 12, max_scrollback: 1_000)
    painter = Vibe.TUI.TerminalPainter.new(80, 12)

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(:assistant_stream_started, session_id, %{})
      )

    {_, painter} = paint_screen(loop, terminal, painter)

    painter =
      Enum.reduce(1..20, painter, fn index, painter ->
        :ok =
          Vibe.Session.emit_transient_event(
            session,
            Vibe.UI.Event.new(:assistant_delta, session_id, %{text: "stream line #{index}\n"})
          )

        {_screen, painter} = paint_screen(loop, terminal, painter)
        painter
      end)

    {_screen, _painter} = paint_screen(loop, terminal, painter)
    :ok = Ghostty.Terminal.scroll(terminal, -1_000)
    {:ok, scrollback} = Ghostty.Terminal.snapshot(terminal, :plain)

    assert scrollback =~ "stream line 20"
    assert count_occurrences(scrollback, "openai_codex:gpt-5.5") <= 2
  end

  test "runtime repaint preserves native scrollback without cloning full frames" do
    session_id = "scrollback-repaint-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 80,
        height: 10,
        session_server: session,
        event_target: self()
      )

    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 80, rows: 10, max_scrollback: 1_000)

    painter =
      Enum.reduce(1..30, Vibe.TUI.TerminalPainter.new(80, 10), fn index, painter ->
        :ok =
          Vibe.Session.emit_transient_event(
            session,
            Vibe.UI.Event.new(:assistant_message_added, session_id, %{text: "message #{index}"})
          )

        {_screen, painter} = paint_screen(loop, terminal, painter)
        painter
      end)

    {_screen, _painter} = paint_screen(loop, terminal, painter)
    assert %{total: total, len: 10} = Ghostty.Terminal.scrollbar(terminal)
    assert total > 10

    :ok = Ghostty.Terminal.scroll(terminal, -1_000)
    {:ok, scrollback} = Ghostty.Terminal.snapshot(terminal, :plain)

    assert scrollback =~ "message 1"
    assert scrollback =~ "message 30"
    assert count_occurrences(scrollback, "message 30") == 1
  end

  test "loader advances from background ticks without input" do
    session_id = "loader-ui-#{System.unique_integer([:positive])}"

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        session_id: session_id,
        event_target: self(),
        loader_tick_ms: 1
      )

    assert :ok = Vibe.UI.Bus.emit(session_id, :assistant_stream_started, %{})
    assert_receive {TerminalLoop, :event, :loader_tick}, 300

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(
             plain,
             &(&1 in ["  ⋰ Thinking…", "  ⋱ Thinking…", "  ✧ Thinking…", "  ✦ Thinking…"])
           )
  end

  test "loader says working while local tool work is running" do
    session_id = "loader-tool-#{System.unique_integer([:positive])}"

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        session_id: session_id,
        event_target: self(),
        loader_tick_ms: 1
      )

    assert :ok = Vibe.UI.Bus.emit(session_id, :assistant_stream_started, %{})

    assert :ok =
             Vibe.UI.Bus.emit(
               session_id,
               :tool_started,
               Vibe.UI.ToolEvent.started(id: "eval-1", name: :eval)
             )

    assert_receive {TerminalLoop, :event, :loader_tick}, 300

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(
             plain,
             &(&1 in ["  ⋰ Working…", "  ⋱ Working…", "  ✧ Working…", "  ✦ Working…"])
           )
  end

  test "starts loader ticks when attaching to an already-working session" do
    session_id = "loader-attach-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    assert :ok =
             Vibe.Session.emit_transient_event(
               session,
               Vibe.UI.Event.new(:assistant_stream_started, session_id, %{})
             )

    {:ok, _loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        session_server: session,
        event_target: self(),
        loader_tick_ms: 1
      )

    assert_receive {TerminalLoop, :event, :loader_tick}, 300
  end

  test "notifies event target for asynchronous UI updates" do
    ask = fn _text, _opts -> {:ok, "done"} end

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        ask_fun: ask,
        event_target: self()
      )

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    assert_receive {TerminalLoop, :event, %{type: :prompt_submitted}}, 500
    assert_receive {TerminalLoop, :event, %{type: :user_message_added}}, 500
    assert_receive {TerminalLoop, :event, %{type: :assistant_message_added}}, 500
  end

  defp replayed_phoenix_events(session_id) do
    prompt =
      "Create a new phoenix project in ~/Development and let's implement tic tac toe game there"

    [
      Vibe.UI.Event.new(:user_message_added, session_id, %{text: prompt}),
      Vibe.UI.Event.new(:assistant_stream_started, session_id, %{}),
      tool_started(session_id, "eval-1", :eval, %{
        code: "Cmd.run([\"mix\", \"phx.new\"], timeout: #{@long_command_timeout_ms})"
      }),
      tool_finished(session_id, "eval-1", :eval, phoenix_output(70), :text),
      tool_started(session_id, "read-router", :read, %{
        path: "/Users/dannote/Development/tic_tac_toe/lib/tic_tac_toe_web/router.ex"
      }),
      tool_started(session_id, "read-home", :read, %{
        path:
          "/Users/dannote/Development/tic_tac_toe/lib/tic_tac_toe_web/controllers/page_html/home.html.heex"
      }),
      tool_started(session_id, "read-css", :read, %{
        path: "/Users/dannote/Development/tic_tac_toe/assets/css/app.css"
      }),
      tool_finished(session_id, "read-router", :read, read_output("router.ex", 45), nil),
      tool_finished(session_id, "read-home", :read, read_output("home.html.heex", 180), nil),
      tool_finished(session_id, "read-css", :read, read_output("app.css", 90), nil),
      tool_started(session_id, "read-mix", :read, %{
        path: "/Users/dannote/Development/tic_tac_toe/mix.exs"
      }),
      tool_finished(session_id, "read-mix", :read, read_output("mix.exs", 100), nil)
    ]
  end

  defp paint_screen(loop, terminal, painter) do
    {frame, painter} =
      Vibe.TUI.TerminalPainter.render(
        painter,
        TerminalLoop.render_full(loop),
        TerminalLoop.full_cursor_position(loop)
      )

    :ok = Ghostty.Terminal.write(terminal, frame)
    {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
    {screen, painter}
  end

  defp tool_started(session_id, id, name, args) do
    Vibe.UI.Event.new(
      :tool_started,
      session_id,
      Vibe.UI.ToolEvent.started(id: id, name: name, args: args)
    )
  end

  defp tool_finished(session_id, id, name, output, format) do
    Vibe.UI.Event.new(
      :tool_finished,
      session_id,
      Vibe.UI.ToolEvent.finished(
        id: id,
        name: name,
        output: %{output: output, output_format: format || :text}
      )
    )
  end

  defp phoenix_output(lines) do
    Enum.map_join(1..lines, "\n", fn index ->
      "* creating tic_tac_toe/generated_file_#{index}.ex"
    end)
  end

  defp read_output(name, lines) do
    %{
      path: name,
      language: "elixir",
      omitted_lines: 0,
      omitted_bytes: 0,
      content: Enum.map_join(1..lines, "\n", &"#{name} line #{&1}")
    }
  end

  defp last_non_blank_line(screen) do
    screen
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.find("", &(String.trim(&1) != ""))
  end

  defp count_occurrences(text, pattern) do
    text
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end

  defp wait_for_output(output, text) do
    deadline = System.monotonic_time(:millisecond) + 500
    do_wait_for_output(output, text, deadline)
  end

  defp do_wait_for_output(output, text, deadline) do
    {_input, contents} = StringIO.contents(output)

    if contents =~ text do
      {:ok, contents}
    else
      remaining = deadline - System.monotonic_time(:millisecond)

      if remaining > 0 do
        Process.sleep(10)
        do_wait_for_output(output, text, deadline)
      else
        {:error, contents}
      end
    end
  end

  test "writes trace artifacts when compile-time debug tracing is enabled" do
    trace_dir =
      Path.join(System.tmp_dir!(), "vibe-tui-trace-#{System.unique_integer([:positive])}")

    {:ok, loop} =
      TerminalLoop.start_link(output: false, width: 60, height: 20, trace_dir: trace_dir)

    :ok = TerminalLoop.input(loop, "/")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :escape})

    assert File.exists?(Path.join(trace_dir, "metadata.json"))
    assert File.exists?(Path.join(trace_dir, "trace.jsonl"))
    assert [_ | _] = Path.join([trace_dir, "frames", "*.txt"]) |> Path.wildcard()
    assert [_ | _] = Path.join([trace_dir, "snapshots", "*.json"]) |> Path.wildcard()
    assert Vibe.TUI.Trace.audit(trace_dir).ok?

    File.rm_rf!(trace_dir)
  end

  test "cancelled prompt is rendered in chat history" do
    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 24,
        ask_fun: fn _text, _opts ->
          Process.sleep(@long_prompt_sleep_ms)
          {:ok, "ok"}
        end
      )

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    Process.sleep(100)
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :escape})

    plain =
      wait_until_render(loop, &Enum.any?(&1, fn line -> String.contains?(line, "Cancelled.") end))

    message_index = Enum.find_index(plain, &String.contains?(&1, "hello"))
    cancelled_index = Enum.find_index(plain, &String.contains?(&1, "Cancelled."))
    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))

    assert message_index
    assert cancelled_index
    assert footer_index
    assert message_index < cancelled_index
    assert cancelled_index < footer_index
    refute Enum.any?(plain, &String.contains?(&1, "! Cancelled."))
  end

  test "confirmation appears above footer like autocomplete without clearing chat history" do
    ask = fn _text, _opts -> {:ok, "ok"} end
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 30, ask_fun: ask)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    Process.sleep(50)
    :ok = TerminalLoop.input(loop, "/clear")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    wait_until_render(
      loop,
      &Enum.any?(&1, fn line -> String.contains?(line, "Clear session?") end)
    )

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))
    confirmation_index = Enum.find_index(plain, &String.contains?(&1, "Clear session?"))

    assert Enum.any?(plain, &String.contains?(&1, "hello"))
    assert confirmation_index
    assert Enum.any?(plain, &String.contains?(&1, "→ Yes"))
    assert prompt_index == footer_index + 1
    assert confirmation_index < footer_index
  end

  test "keeps footer directly above prompt when autocomplete is visible" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 20)

    _initial = TerminalLoop.render(loop)
    :ok = TerminalLoop.input(loop, "/se")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))
    autocomplete_index = Enum.find_index(plain, &String.contains?(&1, "/sessions"))

    assert autocomplete_index
    assert footer_index
    assert prompt_index == footer_index + 1
    assert autocomplete_index < footer_index
  end

  defp picker_plain(input) do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 120, height: 30)
    :ok = TerminalLoop.input(loop, input)

    if input != "/" do
      :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    end

    title = picker_title(input)
    wait_until_render(loop, &Enum.any?(&1, fn line -> String.trim(line) == title end))
  end

  defp picker_title("/"), do: "Commands"

  defp picker_title("/" <> command),
    do: command |> String.capitalize() |> String.replace("_", " ")

  defp wait_until_render(
         loop,
         fun,
         deadline \\ System.monotonic_time(:millisecond) + @render_wait_timeout_ms
       ) do
    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    cond do
      fun.(plain) ->
        plain

      System.monotonic_time(:millisecond) < deadline ->
        Process.sleep(10)
        wait_until_render(loop, fun, deadline)

      true ->
        plain
    end
  end

  defp selector_rendered_once?(plain, title) do
    Enum.count(plain, &(String.trim(&1) == title)) == 1
  end

  defp picker_panel_shape(plain, title) do
    title_index = Enum.find_index(plain, &(String.trim(&1) == title))

    [
      blank_line?(Enum.at(plain, title_index - 1)),
      String.trim(Enum.at(plain, title_index)) == title,
      blank_line?(Enum.at(plain, title_index + 1)),
      String.starts_with?(Enum.at(plain, title_index + 2), "  › ")
    ]
    |> then(fn
      [true, true, true, true] -> {:blank, :title, :blank, :selected_row}
      [true, true, true, false] -> {:blank, :title, :blank, :other}
    end)
  end

  defp selected_row_prefix(plain, title) do
    title_index = Enum.find_index(plain, &(String.trim(&1) == title))
    plain |> Enum.at(title_index + 2) |> String.slice(0, 4)
  end

  defp selected_picker_row(plain) do
    Enum.find(plain, &String.starts_with?(&1, "  › ")) || flunk("no selected picker row")
  end

  defp picker_has_margin_before_footer?(plain) do
    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    footer_index && footer_index > 0 && blank_line?(Enum.at(plain, footer_index - 1))
  end

  defp picker_top_margin_visible?(plain, title) do
    title_index = Enum.find_index(plain, &(String.trim(&1) == title))
    title_index && title_index > 0 && blank_line?(Enum.at(plain, title_index - 1))
  end

  defp blank_line?(line), do: String.trim(line || "") == ""

  defp autocomplete_artifact?(plain) do
    Enum.any?(plain, &(String.trim(&1) == "Completions")) or
      Enum.any?(plain, &(String.trim(&1) == "No matches"))
  end

  test "tracks editor cursor position inside the prompt" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12)

    assert TerminalLoop.cursor_position(loop) == {8, 3}
    :ok = TerminalLoop.input(loop, "hello")
    assert TerminalLoop.cursor_position(loop) == {8, 8}
  end

  test "tracks editor cursor position across prompt newlines" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter, mods: [:shift]})
    :ok = TerminalLoop.input(loop, "world")

    assert TerminalLoop.cursor_position(loop) == {9, 8}
  end

  test "multiline paste inserts into prompt without submitting" do
    parent = self()

    ask = fn text, _opts ->
      send(parent, {:submitted, text})
      {:ok, "submitted"}
    end

    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12, ask_fun: ask)

    :ok = TerminalLoop.input(loop, "hello\nworld")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "hello"))
    assert Enum.any?(plain, &String.contains?(&1, "world"))
    refute_received {:submitted, _text}
  end

  test "tracks resize" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)
    assert :ok = TerminalLoop.resize(loop, 100, 30)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &(String.length(&1) <= 100))
  end
end
