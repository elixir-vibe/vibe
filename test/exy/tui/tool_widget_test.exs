defmodule Exy.TUI.ToolWidgetTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Theme, Widget, Width}

  test "dispatches elixir_eval by atom name" do
    lines =
      DSL.tool(%{
        id: "eval-1",
        name: :elixir_eval,
        status: :ok,
        args: %{code: "1 + 1"},
        output: "2",
        expanded?: true
      })
      |> Widget.render(80, Theme.default())

    plain = Enum.map(lines, &Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "elixir_eval"))
    assert Enum.all?(plain, &String.starts_with?(&1, " "))
    assert Enum.all?(plain, &String.ends_with?(&1, " "))
    refute "params:" in plain
    refute "output:" in plain
    assert Enum.any?(plain, &(String.trim(&1) == ""))
    assert Enum.any?(plain, &String.contains?(&1, "✓"))
    refute Enum.any?(plain, &String.contains?(&1, "ok"))
  end

  test "elixir_eval shows timeout in header and unwraps output envelope" do
    plain =
      %{
        id: "eval-1",
        name: :elixir_eval,
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
      %{id: "eval-1", name: :elixir_eval, status: :ok, args: %{code: "1 + 1"}, output: "2"}
      |> DSL.tool()
      |> Widget.render(80, Theme.default())
      |> List.first()
      |> IO.iodata_to_binary()

    assert line =~ IO.ANSI.format([:bright, "elixir_eval"], true) |> IO.iodata_to_binary()
    refute line =~ "48;2"
  end

  test "truncates tool output with reusable shortcut hint" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{id: "tool", name: :elixir_eval, status: :ok, args: %{code: "many()"}, output: output}
      |> DSL.tool()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "… (4 more lines, ctrl+o to expand)"))
  end

  test "does not truncate output when global truncation is off" do
    output = Enum.map_join(1..12, "\n", &"line #{&1}")

    plain =
      %{
        id: "tool",
        name: :elixir_eval,
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

  test "dispatches AST and LSP widgets" do
    ast =
      DSL.tool(%{
        id: "ast",
        name: :elixir_ast,
        status: :ok,
        args: %{action: :search},
        output: [1, 2],
        expanded?: true
      })

    lsp =
      DSL.tool(%{
        id: "lsp",
        name: :elixir_lsp,
        status: :ok,
        args: %{action: :diagnostics},
        output: [],
        expanded?: true
      })

    assert ast
           |> Widget.render(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.contains?(&1, "elixir_ast"))

    assert lsp
           |> Widget.render(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.contains?(&1, "0 diagnostics"))
  end
end
