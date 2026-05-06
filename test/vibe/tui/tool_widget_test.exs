defmodule Vibe.TUI.ToolWidgetTest do
  use ExUnit.Case, async: true

  alias Vibe.Code.AST.Result
  alias Vibe.TUI
  alias Vibe.TUI.{Theme, Widget, Width}

  @long_command_timeout_ms 120_000
  @expanded_command_timeout_ms 10_000
  @large_output_lines 10_000
  @eval_render_budget_us 100_000
  @read_render_budget_us 1_000_000

  test "dispatches eval by atom name" do
    lines =
      TUI.tool(%{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{code: "1 + 1"},
        output: "2",
        expanded?: true
      })
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "eval"))
    assert Enum.all?(plain, &String.starts_with?(&1, " "))
    assert Enum.all?(plain, &String.ends_with?(&1, " "))
    refute "params:" in plain
    refute "output:" in plain
    assert Enum.any?(plain, &(String.trim(&1) == ""))
    assert Enum.any?(plain, &String.contains?(&1, "✓"))
    refute Enum.any?(plain, &String.contains?(&1, "ok"))
  end

  test "eval renders web markdown output in the tool widget" do
    plain =
      %{
        id: "eval-web",
        name: :eval,
        status: :ok,
        args: %{
          code:
            "Web.fetch!(\"https://example.com\", format: :html) |> Web.select!(\"h1\") |> MD.doc()"
        },
        output:
          "## Fetched selection\n\nhttps://example.com · 200 html · selector `h1`\n\n# Example Domain",
        output_format: :markdown,
        expanded?: true
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "Fetched selection"))
    assert Enum.any?(plain, &String.contains?(&1, "Example Domain"))
    refute Enum.any?(plain, &String.contains?(&1, "```"))
  end

  test "eval renders output when output_parts is empty" do
    plain =
      %{
        id: "eval-empty-parts",
        name: :eval,
        status: :ok,
        args: %{code: "File.cwd!()"},
        output: ~s("/workspace"),
        output_format: :inspect,
        output_parts: []
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "/workspace"))
  end

  test "eval rendering trims only one trailing newline" do
    plain =
      %{
        id: "eval-final-newline",
        name: :eval,
        status: :ok,
        args: %{code: "IO.puts(\"hello\")"},
        output: "hello\n\n",
        output_format: :text
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(fn line -> line |> Width.visible_text() |> String.trim_trailing() end)

    assert "   hello" in plain
    assert Enum.count(plain, &(&1 == "")) == 2
  end

  test "eval shows timeout in header and unwraps output envelope" do
    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{"code" => "File.cwd!()", "timeout" => 1000},
        output: %{output: ~s("/tmp")}
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, "File.cwd!()")
    assert String.contains?(header, "1s")
    assert {code_index, _} = :binary.match(header, "File.cwd!()")
    assert {timeout_index, _} = :binary.match(header, "1s")
    assert code_index < timeout_index
    refute String.contains?(header, "timeout")
    refute String.contains?(header, "1000ms")
    refute Enum.any?(plain, &String.contains?(&1, "%{output:"))
    assert Enum.any?(plain, &String.contains?(&1, ~s("/tmp")))
  end

  test "eval header highlights command summaries with dim syntax colors" do
    line =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{
          code: "Cmd.run([\"bash\", \"-lc\", \"pwd\"], timeout: #{@long_command_timeout_ms})"
        },
        output: "ok"
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert Width.visible_text(line) =~
             "Cmd.run([\"bash\", \"-lc\", \"pwd\"], timeout: #{@long_command_timeout_ms})"

    assert line =~ "38;2;154;154;154"
    assert Width.visible_length(line) <= 100
  end

  test "eval header highlights assigned command summaries with dim syntax colors" do
    line =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{
          code:
            ~S|task = Cmd.start(["sh", "-c", "for i in 1 2 3; do echo tick:$i; sleep 10; done"])|
        },
        output: "ok"
      }
      |> TUI.tool()
      |> Widget.render(120, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert Width.visible_text(line) =~ "task = Cmd.start"
    assert line =~ "38;2;154;154;154"
    assert Width.visible_length(line) <= 120
  end

  test "eval header highlights arbitrary Elixir summaries with dim syntax colors" do
    line =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{code: ~S|%{home: System.user_home!(), ok: true}|},
        output: "%{home: \"/Users/dannote\", ok: true}",
        output_format: :inspect
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert Width.visible_text(line) =~ ~S|%{home: System.user_home!(), ok: true}|
    assert line =~ "38;2;154;154;154"
  end

  test "streamed eval params are syntax highlighted while preparing" do
    line =
      %{
        id: "eval-streaming-params",
        name: :eval,
        status: :preparing,
        args: %{code: ~S|task = Cmd.start(["sh", "-c", "echo tick"] )|}
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert Width.visible_text(line) =~ "task = Cmd.start"
    assert line =~ "38;2;154;154;154"
  end

  test "eval command output strips destructive terminal controls but preserves colors and padding" do
    lines =
      %{
        id: "eval-ansi",
        name: :eval,
        status: :ok,
        args: %{code: ~S|Cmd.run(["sh", "-c", "printf ..."] )|},
        output_parts: [
          %{
            output:
              "\e[31mred\e[0m normal\nstart\rfinal\n\e[2J\e[Hafter-clear\n\e]0;title\aafter-osc",
            format: :text
          }
        ]
      }
      |> TUI.tool()
      |> Widget.render(60, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    rendered = IO.iodata_to_binary(lines)

    assert rendered =~ "\e[31m"
    refute rendered =~ "\e[2J"
    refute rendered =~ "\e[H"
    refute rendered =~ "\e]0;"
    assert Enum.any?(plain, &String.contains?(&1, "red normal"))
    assert Enum.any?(plain, &String.contains?(&1, "after-clear"))
    assert Enum.any?(plain, &String.contains?(&1, "after-osc"))
    assert Enum.all?(plain, &(Width.visible_length(&1) <= 60))
    assert Enum.all?(plain, &String.starts_with?(&1, " "))
    assert Enum.all?(plain, &String.ends_with?(&1, " "))
  end

  test "text output is not syntax highlighted" do
    lines =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{code: ~S|Cmd.run(["mix", "phx.new"] )|},
        output: "* creating tic_tac_toe/lib/tic_tac_toe.ex",
        output_format: :text
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())

    output_line = Enum.find(lines, &(Width.visible_text(&1) =~ "* creating"))

    assert output_line
    refute IO.iodata_to_binary(output_line) =~ "38;2;154;154;154"
  end

  test "inspect output is syntax highlighted" do
    lines =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{code: "%{ok: true}"},
        output: "%{ok: true}",
        output_format: :inspect
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())

    output_line = Enum.find(lines, &(Width.visible_text(&1) =~ "%{ok: true}"))

    assert output_line
    assert IO.iodata_to_binary(output_line) =~ "\e[38;2;"
  end

  test "eval map and struct return values stay syntax highlighted through tool event path" do
    code =
      ~S|%{answer: 42, elixir: System.version(), example_struct: %URI{scheme: "https", host: "example.com"}}|

    assert {:ok, action_result} =
             Vibe.Actions.Eval.run(%{code: code}, %{session_id: "tui-color-eval"})

    lines =
      Vibe.UI.ToolEvent.finished(
        id: "eval-1",
        name: :eval,
        args: %{code: code},
        output: {:ok, action_result, []}
      )
      |> Map.from_struct()
      |> Map.put(:truncate?, false)
      |> TUI.tool()
      |> Widget.render(120, Theme.default())

    rendered = IO.iodata_to_binary(lines)
    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "%{"
    assert plain =~ "answer: 42"
    assert plain =~ ~S|example_struct: %URI{|
    assert rendered =~ "\e[38;2;"
  end

  test "eval header ellipsizes long commands before trailing metadata" do
    line =
      %{
        id: "eval-1",
        name: :eval,
        status: :error,
        args: %{
          code:
            ~S|{:ok, job} = Cmd.start(["sh", "-c", "sleep 30; echo long-running-task-complete"], timeout: 60_000); long_task_info = %{id: job.id, pid: inspect(job.pid), output: Cmd.output(job)}|,
          timeout: 5_000
        },
        output: %{error: "boom"}
      }
      |> TUI.tool()
      |> Widget.render(120, Theme.default())
      |> List.first()
      |> Width.visible_text()

    assert line =~ "… · 5s"
    assert Width.visible_length(line) <= 120
  end

  test "eval header uses available line width for long commands" do
    code =
      "dev = Path.join(System.user_home!(), \"Development\") base = Path.join(dev, \"vibe\") File.ls!(base)"

    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{"code" => code, "timeout" => @long_command_timeout_ms},
        output: "[]"
      }
      |> TUI.tool()
      |> Widget.render(120, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, "File.ls!")
    assert String.length(header) <= 120
  end

  test "expanded eval errors render without map wrapper" do
    lines =
      %{
        id: "eval-error",
        name: :eval,
        status: :error,
        args: %{
          code: ~S|{:ok, job} = Cmd.start(["sh", "-c", "sleep 30"]); Cmd.status(job)|,
          timeout: 5_000
        },
        output: %{error: "** (RuntimeError) boom\n    nofile:1: (file)"},
        expanded?: true,
        truncate?: false
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())

    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)
    rendered = IO.iodata_to_binary(lines)

    assert plain =~ "RuntimeError"
    refute plain =~ "%{error:"
    assert rendered =~ "38;2;204;102;102"
  end

  test "eval renders mixed IO and returned value with spacing and inspect highlighting" do
    lines =
      TUI.tool(%{
        id: "eval-io-value",
        name: :eval,
        status: :ok,
        args: %{code: ~S|IO.puts("hello"); {:ok, %{answer: 42}}|},
        output: "hello\n\n{:ok, %{answer: 42}}",
        output_format: :text,
        output_parts: [
          %{output: "hello\n", format: :text},
          %{output: "{:ok, %{answer: 42}}", format: :inspect}
        ]
      })
      |> Widget.render(100, Theme.default())

    rendered = IO.iodata_to_binary(lines)
    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "hello"
    assert plain =~ "{:ok, %{answer: 42}}"

    hello_index = Enum.find_index(lines, &(Width.visible_text(&1) =~ "hello"))

    result_index =
      Enum.find_index(lines, fn line ->
        line |> Width.visible_text() |> String.trim_leading() |> String.starts_with?("{:ok")
      end)

    assert is_integer(hello_index)
    assert is_integer(result_index)
    assert result_index > hello_index

    assert Enum.any?(Enum.slice(lines, (hello_index + 1)..(result_index - 1)), fn line ->
             line |> Width.visible_text() |> String.trim() == ""
           end)

    assert rendered =~ "38;2;224;108;117"
  end

  test "eval renders markdown-formatted output as markdown" do
    markdown = "## Command ok\n\n- Command: `mix test`\n\n```text\n1 test, 0 failures\n```"

    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{code: "Cmd.run([\"mix\", \"test\"]) |> MD.doc()"},
        output: markdown,
        output_format: :markdown
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    rendered = Enum.join(plain, "\n")
    assert rendered =~ "Command ok"
    assert rendered =~ "Command: mix test"
    assert rendered =~ "1 test, 0 failures"
    refute rendered =~ ~S(\n)
    refute rendered =~ ~s("## Command ok)
  end

  test "expanded eval keeps full code in the body without debug labels" do
    code = ~S|System.cmd("ls", ["-la"], stderr_to_stdout: true)|

    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{"code" => code, "timeout" => @expanded_command_timeout_ms},
        output: "total 0",
        output_parts: [%{output: "total 0", format: :text}],
        truncate?: false
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, "eval")
    assert String.contains?(header, "10s")
    refute String.contains?(header, code)
    refute String.contains?(header, "eval • eval")
    refute Enum.any?(plain, &String.contains?(&1, "code:"))
    refute Enum.any?(plain, &String.contains?(&1, "output:"))
    assert Enum.any?(plain, &String.contains?(&1, code))
    assert Enum.any?(plain, &String.contains?(&1, "total 0"))
  end

  test "tool title is bold without status background" do
    line =
      %{id: "eval-1", name: :eval, status: :ok, args: %{code: "1 + 1"}, output: "2"}
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert line =~ "38;2;178;148;187"
    assert line =~ IO.ANSI.format([:bright, "eval"], true) |> IO.iodata_to_binary()
    refute line =~ "48;2"
  end

  test "failed tool output is red and padded" do
    lines =
      %{
        id: "eval-1",
        name: :eval,
        status: :error,
        args: %{code: "raise \"boom\""},
        output: %{error: "boom"}
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    ansi = IO.iodata_to_binary(lines)

    assert Enum.any?(plain, &String.contains?(&1, "×"))
    assert Enum.any?(plain, &String.contains?(&1, "  boom"))
    assert Enum.all?(plain, &String.starts_with?(&1, " "))
    assert ansi =~ "38;2;204;102;102"
  end

  test "eval truncates large output before wrapping" do
    output =
      Enum.map_join(1..@large_output_lines, "\n", &"line #{&1} #{String.duplicate("x", 100)}")

    tool = %{id: "tool", name: :eval, status: :ok, args: %{code: "many()"}, output: output}

    {us, lines} = :timer.tc(fn -> tool |> TUI.tool() |> Widget.render(120, Theme.default()) end)
    plain = Enum.map(lines, &Width.visible_text/1)

    assert us < @eval_render_budget_us
    assert Enum.any?(plain, &String.contains?(&1, "line 10000"))
  end

  test "eval truncates large structured output parts before wrapping" do
    output =
      Enum.map_join(1..@large_output_lines, "\n", &"line #{&1} #{String.duplicate("x", 100)}")

    tool = %{
      id: "tool",
      name: :eval,
      status: :ok,
      args: %{code: "many()"},
      output_parts: [%{output: output, format: :text}]
    }

    {us, lines} = :timer.tc(fn -> tool |> TUI.tool() |> Widget.render(120, Theme.default()) end)
    plain = Enum.map(lines, &Width.visible_text/1)

    assert us < @eval_render_budget_us
    assert Enum.any?(plain, &String.contains?(&1, "… (9992 more lines, ctrl+o to expand)"))
    assert Enum.any?(plain, &String.contains?(&1, "line 10000"))
    refute Enum.any?(plain, &String.contains?(&1, "line 1 "))
    assert Enum.all?(plain, &(Width.visible_length(&1) <= 120))
  end

  test "eval preserves output indentation when wrapping long unbroken lines" do
    output = String.duplicate(".", 120)

    plain =
      %{
        id: "tool",
        name: :eval,
        status: :ok,
        args: %{code: "mix_test()"},
        output_parts: [%{output: output, format: :text}]
      }
      |> TUI.tool()
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    dot_lines = Enum.filter(plain, &String.contains?(&1, "."))

    assert length(dot_lines) > 1
    assert Enum.all?(dot_lines, &String.starts_with?(&1, "   "))
    assert Enum.all?(plain, &(Width.visible_length(&1) <= 40))
  end

  test "eval truncation keeps the tail and shows the shortcut hint first" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{id: "tool", name: :eval, status: :ok, args: %{code: "many()"}, output: output}
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    hint_index =
      Enum.find_index(plain, &String.contains?(&1, "… (4 more lines, ctrl+o to expand)"))

    line_5_index = Enum.find_index(plain, &String.contains?(&1, "line 5"))
    line_12_index = Enum.find_index(plain, &String.contains?(&1, "line 12"))

    assert hint_index
    assert line_5_index
    assert line_12_index
    assert line_5_index > hint_index
    assert line_12_index > line_5_index
    refute Enum.any?(plain, &(String.trim(&1) == "line 1"))
  end

  test "truncates tool output with reusable shortcut hint" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{id: "tool", name: :eval, status: :ok, args: %{code: "many()"}, output: output}
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    hint_index =
      Enum.find_index(plain, &String.contains?(&1, "… (4 more lines, ctrl+o to expand)"))

    assert hint_index
    assert plain |> Enum.at(hint_index - 1) |> String.trim() == ""
  end

  test "does not truncate output when global truncation is off" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{
        id: "tool",
        name: :eval,
        status: :ok,
        args: %{code: "many()"},
        output: output,
        truncate?: false
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    refute Enum.any?(plain, &String.contains?(&1, "ctrl+o"))
    assert Enum.any?(plain, &String.contains?(&1, "line 12"))
  end

  test "renderer failures become error tool blocks" do
    assert Vibe.TUI.ToolWidget.render(
             %{name: :definitely_missing_tool, status: :ok, output: "value"},
             80,
             Theme.default()
           )
  end

  test "write for newly created files renders highlighted source instead of diff markers" do
    lines =
      %{
        id: "write-1",
        name: :write,
        status: :ok,
        args: %{path: "lib/demo.ex"},
        output: %{
          path: "lib/demo.ex",
          change: %{
            path: "lib/demo.ex",
            old: "",
            new: "defmodule Demo do\n  @answer 42\nend\n",
            diff: "+ 1  defmodule Demo do\n+ 2    @answer 42\n+ 3  end"
          }
        }
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())

    rendered = IO.iodata_to_binary(lines)
    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "defmodule Demo do"
    refute plain =~ "+ 1  defmodule Demo do"
    assert rendered =~ "\e[38;2;"
  end

  test "edit diffs syntax-highlight changed source" do
    lines =
      %{
        id: "edit-1",
        name: :edit,
        status: :ok,
        args: %{path: "lib/demo.ex"},
        output: %{
          path: "lib/demo.ex",
          change: %{
            path: "lib/demo.ex",
            old: "defmodule Demo do\n  def answer, do: 41\nend\n",
            new: "defmodule Demo do\n  def answer, do: 42\nend\n",
            diff:
              " 1  defmodule Demo do\n-2    def answer, do: 41\n+2    def answer, do: 42\n 3  end"
          }
        }
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())

    rendered = IO.iodata_to_binary(lines)
    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "-2    def answer, do: 41"
    assert plain =~ "+2    def answer, do: 42"
    assert rendered =~ "\e[38;2;"
  end

  test "read truncates large file content before rendering" do
    content =
      Enum.map_join(1..@large_output_lines, "\n", &"line #{&1} #{String.duplicate("x", 200)}")

    {us, lines} =
      :timer.tc(fn ->
        %{
          id: "read-large",
          name: :read,
          status: :ok,
          args: %{path: "large.ex"},
          output: %{path: "large.ex", content: content, language: "elixir"}
        }
        |> TUI.tool()
        |> Widget.render(120, Theme.default())
      end)

    plain = Enum.map(lines, &Width.visible_text/1)

    assert us < @read_render_budget_us
    assert Enum.any?(plain, &String.contains?(&1, "ctrl+o"))
    refute Enum.any?(plain, &String.contains?(&1, "file truncated by read limit"))
    refute Enum.any?(plain, &String.contains?(&1, "line 9999"))
  end

  test "read shows file read limit only when expanded" do
    content = Enum.map_join(1..12, "\n", &"line #{&1}")

    tool = %{
      id: "read-limited",
      name: :read,
      status: :ok,
      args: %{path: "limited.ex"},
      output: %{
        path: "limited.ex",
        content: content,
        language: "elixir",
        omitted_lines: 398,
        omitted_bytes: 1200
      }
    }

    collapsed =
      tool
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    expanded =
      tool
      |> Map.put(:truncate?, false)
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(collapsed, &String.contains?(&1, "ctrl+o"))
    refute Enum.any?(collapsed, &String.contains?(&1, "file truncated by read limit"))

    refute Enum.any?(expanded, &String.contains?(&1, "ctrl+o"))
    assert Enum.any?(expanded, &String.contains?(&1, "… file truncated by read limit"))
    refute Enum.any?(expanded, &String.contains?(&1, "398 more lines"))
    refute Enum.any?(expanded, &String.contains?(&1, "1200 more bytes"))
  end

  test "renders read output as highlighted code" do
    lines =
      %{
        id: "read-1",
        name: :read,
        status: :ok,
        args: %{path: "lib/demo.ex"},
        output: %{path: "lib/demo.ex", content: "IO.puts(:ok)", language: "elixir"}
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    ansi = IO.iodata_to_binary(lines)

    assert Enum.any?(plain, &String.contains?(&1, "read"))
    assert Enum.any?(plain, &String.contains?(&1, "lib/demo.ex"))
    assert Enum.any?(plain, &String.contains?(&1, "IO.puts(:ok)"))
    assert ansi =~ "\e[38;2;"
  end

  test "renders markdown read output and highlights fenced code" do
    markdown = """
    # Phoenix Vapor

    ```elixir
    defmodule Demo do
      use PhoenixVapor
    end
    ```
    """

    lines =
      %{
        id: "read-md",
        name: :read,
        status: :ok,
        args: %{path: "README.md"},
        output: %{path: "README.md", content: markdown, language: "markdown"}
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())

    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)
    ansi = IO.iodata_to_binary(lines)

    assert plain =~ "Phoenix Vapor"
    assert plain =~ "elixir"
    assert plain =~ "defmodule Demo do"
    refute plain =~ "```"
    assert ansi =~ "38;2;198;120;221"

    lines
    |> Enum.map(&Width.visible_text/1)
    |> Enum.reject(&(String.trim(&1) == "" or String.contains?(&1, "◆ read")))
    |> Enum.each(fn line ->
      assert String.starts_with?(line, "   ")
      assert Width.visible_length(line) <= 80
    end)
  end

  test "renders edit diffs with diff widget colors" do
    lines =
      %{
        id: "edit-1",
        name: :edit,
        status: :ok,
        args: %{path: "demo.txt"},
        output: %{
          path: "demo.txt",
          message: "Successfully replaced 1 block(s) in demo.txt.",
          diff: "-1  old\n+1  new"
        }
      }
      |> TUI.tool()
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    ansi = IO.iodata_to_binary(lines)

    refute Enum.any?(plain, &String.contains?(&1, "Successfully replaced"))
    assert Enum.any?(plain, &String.contains?(&1, "-1  old"))
    assert Enum.any?(plain, &String.contains?(&1, "+1  new"))
    assert ansi =~ "38;2;204;102;102"
    assert ansi =~ "38;2;126;170;115"
  end

  test "dispatches AST and LSP widgets" do
    ast =
      TUI.tool(%{
        id: "ast",
        name: :ast,
        status: :ok,
        args: %{action: :search},
        output: [1, 2],
        expanded?: true
      })

    lsp =
      TUI.tool(%{
        id: "lsp",
        name: :lsp,
        status: :ok,
        args: %{action: :diagnostics},
        output: [],
        expanded?: true
      })

    assert ast
           |> Widget.render(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.contains?(&1, "ast"))

    assert lsp
           |> Widget.render(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.contains?(&1, "0 diagnostics"))
  end

  test "ast replace shows params and rendered diff" do
    result = %Result{
      action: :replace,
      path: "lib/demo.ex",
      pattern: "left - right",
      replacement: "left + right",
      dry_run: true,
      result: [{"lib/demo.ex", 1}],
      diff: [
        %{
          path: "lib/demo.ex",
          diff: "--- lib/demo.ex\n+++ lib/demo.ex\n@@\n-  left - right\n+  left + right"
        }
      ]
    }

    lines =
      TUI.tool(%{
        id: "ast-replace",
        name: :ast,
        status: :ok,
        args: %{
          action: :replace,
          path: "lib/demo.ex",
          pattern: "left - right",
          replacement: "left + right"
        },
        output: result,
        expanded?: true
      })
      |> Widget.render(120, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    rendered = Enum.join(lines, "\n")

    refute rendered =~ "params:"
    assert rendered =~ "left - right"
    assert rendered =~ "left + right"
    refute rendered =~ "matches: 1\n"
    assert rendered =~ "dry-run"
    refute rendered =~ "lib/demo.ex\n   ---"
    assert rendered =~ "-  left - right"
    assert rendered =~ "+  left + right"
  end

  test "ast shows curated params in the header and match list in the body" do
    lines =
      TUI.tool(%{
        id: "ast-search",
        name: :ast,
        status: :ok,
        args: %{"action" => "search", "path" => "lib/demo.ex", "pattern" => "IO.puts(_)"},
        output: [%{path: "lib/demo.ex", line: 1}],
        expanded?: true
      })
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    rendered = Enum.join(lines, "\n")

    assert rendered =~ "ast"
    assert rendered =~ "search"
    assert rendered =~ "lib/demo.ex"
    refute rendered =~ "params:"
    assert rendered =~ "pattern: IO.puts(_)"
    assert rendered =~ "lib/demo.ex:1"
  end

  test "lsp hides raw params and keeps action in the header" do
    lines =
      TUI.tool(%{
        id: "lsp-error",
        name: :lsp,
        status: :error,
        args: %{"action" => "diagnostics", "cwd" => "/tmp/project", "wait_ms" => 1000},
        output: %{error: "missing required parameter: file"},
        expanded?: true
      })
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    rendered = Enum.join(lines, "\n")

    assert rendered =~ "lsp"
    assert rendered =~ "diagnostics"
    assert rendered =~ "1s"
    assert rendered =~ "/tmp/project"
    assert rendered =~ "missing required parameter: file"
    refute rendered =~ "params:"
    refute rendered =~ "wait_ms"
  end
end
