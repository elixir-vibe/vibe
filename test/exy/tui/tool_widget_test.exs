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
    assert "code:" in plain
    assert "output:" in plain
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
