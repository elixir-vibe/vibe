defmodule Vibe.TUI.StressTest do
  use ExUnit.Case, async: false

  alias Vibe.TUI
  alias Vibe.TUI.{TerminalLoop, TerminalPainter, Theme, Widget, Width}
  alias Vibe.Event

  @width 120
  @height 28
  @large_lines 600
  @long_line String.duplicate("x", 180)
  @render_budget_us 1_500_000
  @incremental_budget_us 3_000_000

  test "eval output parts render like plain output under stress" do
    output = large_output(@large_lines)

    plain_tool = %{id: "plain", name: :eval, status: :ok, args: %{code: "many()"}, output: output}

    parts_tool = %{
      id: "parts",
      name: :eval,
      status: :ok,
      args: %{code: "many()"},
      output_parts: [%{output: output, format: :text}]
    }

    {plain_us, plain_lines} = timed_render_tool(plain_tool)
    {parts_us, parts_lines} = timed_render_tool(parts_tool)

    assert plain_us < @render_budget_us
    assert parts_us < @render_budget_us

    plain_text = Enum.map(plain_lines, &Width.visible_text/1)
    parts_text = Enum.map(parts_lines, &Width.visible_text/1)

    assert Enum.any?(plain_text, &String.contains?(&1, "line #{@large_lines}"))
    assert Enum.any?(parts_text, &String.contains?(&1, "line #{@large_lines}"))
    assert Enum.any?(plain_text, &String.contains?(&1, "more lines"))
    assert Enum.any?(parts_text, &String.contains?(&1, "more lines"))
    refute Enum.any?(parts_text, &String.contains?(&1, "line 1 "))
    assert_all_lines_fit(plain_text, @width)
    assert_all_lines_fit(parts_text, @width)
  end

  test "eval header keeps timeout as trailing metadata under long command stress" do
    code =
      ~S|for dir <- ~w(reach quickbeam volt phoenix_vapor phoenix_replay vize_ex oxc_ex), do: Cmd.run(["mix", "test"], cd: dir, timeout: 900_000)|

    lines =
      %{
        id: "eval-header",
        name: :eval,
        status: :ok,
        args: %{code: code, timeout: 900_000},
        output: "ok"
      }
      |> TUI.tool()
      |> Widget.render(@width, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(lines)

    assert header =~ "eval"
    assert header =~ "900s"
    assert {eval_index, _} = :binary.match(header, "eval")
    assert {code_index, _} = :binary.match(header, "for dir")
    assert {timeout_index, _} = :binary.match(header, "900s")
    assert eval_index < code_index
    assert code_index < timeout_index
    assert_all_lines_fit(lines, @width)
  end

  test "terminal repaint survives large history, large eval outputs, and long lines" do
    session_id = "stress-history-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: @width,
        height: @height,
        session_server: session,
        event_target: self()
      )

    {:ok, terminal} =
      Ghostty.Terminal.start_link(cols: @width, rows: @height, max_scrollback: 10_000)

    Enum.each(large_history_events(session_id), fn event ->
      :ok = Vibe.Session.emit_transient_event(session, event)
    end)

    assert_receive {TerminalLoop, :event, %{type: :assistant_message_added}}, 500

    {us, {screen, _painter}} =
      :timer.tc(fn ->
        paint_screen(loop, terminal, TerminalPainter.new(@width, @height))
      end)

    assert us < @render_budget_us
    rows = String.split(screen, "\n", trim: false)

    assert screen =~ "Prompt"
    assert screen =~ "openai_codex:gpt-5.5"
    assert screen =~ "line #{@large_lines}"
    assert Enum.all?(rows, &(String.length(&1) <= @width))
    refute last_non_blank_line(screen) =~ "openai_codex:gpt-5.5"
  end

  test "streaming eval output updates remain bounded" do
    session_id = "stress-stream-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: @width,
        height: @height,
        session_server: session,
        event_target: self()
      )

    {:ok, terminal} =
      Ghostty.Terminal.start_link(cols: @width, rows: @height, max_scrollback: 10_000)

    start =
      tool_event(session_id, :tool_started,
        id: "eval-stream",
        name: :eval,
        args: %{code: "Cmd.run([\"mix\", \"test\"], timeout: 900_000)"}
      )

    :ok =
      Vibe.Session.emit_transient_event(
        session,
        Event.new(:assistant_stream_started, session_id, %{})
      )

    :ok = Vibe.Session.emit_transient_event(session, start)

    {us, painter} =
      :timer.tc(fn ->
        Enum.reduce(1..20, TerminalPainter.new(@width, @height), fn chunk, painter ->
          output = large_output(chunk * 30)

          event =
            tool_event(session_id, :tool_finished,
              id: "eval-stream",
              name: :eval,
              args: %{code: "Cmd.run([\"mix\", \"test\"], timeout: 900_000)"},
              output: %{output: output, output_format: :text}
            )

          :ok = Vibe.Session.emit_transient_event(session, event)
          # Sync flush: GenServer call forces mailbox processing
          _ = TerminalLoop.render_snapshot(loop)
          {_screen, painter} = paint_screen(loop, terminal, painter)
          painter
        end)
      end)

    assert us < @incremental_budget_us

    _ = TerminalLoop.render_snapshot(loop)
    {screen, _painter} = paint_screen(loop, terminal, painter)
    assert screen =~ "line 600"
    assert screen =~ "Prompt"
    assert screen =~ "openai_codex:gpt-5.5"
  end

  defp timed_render_tool(tool) do
    :timer.tc(fn ->
      tool
      |> TUI.tool()
      |> Widget.render(@width, Theme.default())
    end)
  end

  defp large_history_events(session_id) do
    Enum.flat_map(1..18, fn index ->
      [
        Event.new(:user_message_added, session_id, %{text: "Run test batch #{index}"}),
        Event.new(:assistant_stream_started, session_id, %{}),
        tool_event(session_id, :tool_started,
          id: "eval-#{index}",
          name: :eval,
          args: %{code: long_eval_code(index)}
        ),
        tool_event(session_id, :tool_finished,
          id: "eval-#{index}",
          name: :eval,
          args: %{code: long_eval_code(index)},
          output: %{
            output: large_output(if(rem(index, 3) == 0, do: @large_lines, else: 80)),
            output_format: :text,
            output_parts: [
              %{
                output: large_output(if(rem(index, 3) == 0, do: @large_lines, else: 80)),
                format: :text
              }
            ]
          }
        ),
        Event.new(:assistant_message_added, session_id, %{text: "Finished batch #{index}"})
      ]
    end)
  end

  defp long_eval_code(index) do
    ~s|for dir <- ~w(reach quickbeam volt phoenix_vapor phoenix_replay vize_ex oxc_ex batch_#{index}), do: Cmd.run(["mix", "test"], cd: dir, timeout: 900_000)|
  end

  defp large_output(lines) do
    Enum.map_join(1..lines, "\n", fn index ->
      "line #{index} #{@long_line}"
    end)
  end

  defp tool_event(session_id, type, fields) do
    event =
      case type do
        :tool_started -> tool_payload_started(fields)
        :tool_finished -> tool_payload_finished(fields)
      end

    Event.new(type, session_id, event)
  end

  defp drain_loop_events do
    receive do
      {TerminalLoop, :event, _} -> drain_loop_events()
    after
      100 -> :ok
    end
  end

  defp paint_screen(loop, terminal, painter) do
    {lines, cursor} = TerminalLoop.render_snapshot(loop)
    {frame, painter} = TerminalPainter.render(painter, lines, cursor)

    :ok = Ghostty.Terminal.write(terminal, frame)
    {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
    {screen, painter}
  end

  defp assert_all_lines_fit(lines, width) do
    assert Enum.all?(lines, &(Width.visible_length(&1) <= width))
  end

  defp last_non_blank_line(screen) do
    screen
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.find("", &(String.trim(&1) != ""))
  end

  defp tool_payload_started(opts), do: Vibe.Event.Tool.started(Vibe.Tool.Event.started(opts))
  defp tool_payload_finished(opts), do: Vibe.Event.Tool.finished(Vibe.Tool.Event.finished(opts))
end
