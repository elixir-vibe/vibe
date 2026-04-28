defmodule Exy.TUI.ToolWidgetTest do
  use ExUnit.Case, async: true

  alias Exy.TUI

  alias Exy.TUI.{Theme, Widget, Width}

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
    assert String.contains?(header, "File.cwd!() 1s")
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
        args: %{code: ~S|Cmd.run(["bash", "-lc", "pwd"], timeout: 120_000)|},
        output: "ok"
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert Width.visible_text(line) =~ ~S|Cmd.run(["bash", "-lc", "pwd"], timeout: 120_000)|
    assert line =~ "38;2;154;154;154"
    assert Width.visible_length(line) <= 100
  end

  test "eval header does not dim-highlight non-command summaries" do
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
    refute line =~ "38;2;154;154;154"
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
             Exy.Actions.Eval.run(%{code: code}, %{session_id: "tui-color-eval"})

    lines =
      Exy.UI.ToolEvent.finished(
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

  test "eval header uses available line width for long commands" do
    code =
      "dev = Path.join(System.user_home!(), \"Development\") base = Path.join(dev, \"exy\") File.ls!(base)"

    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{"code" => code, "timeout" => 120_000},
        output: "[]"
      }
      |> TUI.tool()
      |> Widget.render(120, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, "File.ls!")
    assert String.length(header) <= 120
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

  test "expanded eval shows command in header without duplicating command section" do
    code = ~S|System.cmd("ls", ["-la"], stderr_to_stdout: true)|

    plain =
      %{
        id: "eval-1",
        name: :eval,
        status: :ok,
        args: %{"code" => code, "timeout" => 10_000},
        output: "total 0",
        truncate?: false
      }
      |> TUI.tool()
      |> Widget.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, code)
    refute Enum.any?(plain, &String.contains?(&1, "command:"))
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
    output = Enum.map_join(1..10_000, "\n", &"line #{&1} #{String.duplicate("x", 100)}")
    tool = %{id: "tool", name: :eval, status: :ok, args: %{code: "many()"}, output: output}

    {us, lines} = :timer.tc(fn -> tool |> TUI.tool() |> Widget.render(120, Theme.default()) end)
    plain = Enum.map(lines, &Width.visible_text/1)

    assert us < 50_000
    assert Enum.any?(plain, &String.contains?(&1, "line 10000"))
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
    assert Exy.TUI.ToolWidget.render(
             %{name: :definitely_missing_tool, status: :ok, output: "value"},
             80,
             Theme.default()
           )
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

    assert Enum.any?(plain, &String.contains?(&1, "Successfully replaced"))
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

  test "ast hides raw params and keeps action and path context visible" do
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
    refute rendered =~ "pattern"
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
