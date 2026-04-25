defmodule Exy.TUI.ToolWidgetTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Theme, Widget, Width}

  test "dispatches eval by atom name" do
    lines =
      DSL.tool(%{
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
      |> DSL.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    header = List.first(plain)
    assert String.contains?(header, "File.cwd!() 1s")
    refute String.contains?(header, "timeout")
    refute String.contains?(header, "1000ms")
    refute Enum.any?(plain, &String.contains?(&1, "%{output:"))
    assert Enum.any?(plain, &String.contains?(&1, ~s("/tmp")))
  end

  test "tool title is bold without status background" do
    line =
      %{id: "eval-1", name: :eval, status: :ok, args: %{code: "1 + 1"}, output: "2"}
      |> DSL.tool()
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
      |> DSL.tool()
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    ansi = IO.iodata_to_binary(lines)

    assert Enum.any?(plain, &String.contains?(&1, "×"))
    assert Enum.any?(plain, &String.contains?(&1, "  boom"))
    assert Enum.all?(plain, &String.starts_with?(&1, " "))
    assert ansi =~ "38;2;204;102;102"
  end

  test "truncates tool output with reusable shortcut hint" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{id: "tool", name: :eval, status: :ok, args: %{code: "many()"}, output: output}
      |> DSL.tool()
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
      |> DSL.tool()
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
      |> DSL.tool()
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
      |> DSL.tool()
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
      DSL.tool(%{
        id: "ast",
        name: :ast,
        status: :ok,
        args: %{action: :search},
        output: [1, 2],
        expanded?: true
      })

    lsp =
      DSL.tool(%{
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
end
