defmodule Exy.TUI do
  @moduledoc """
  Declarative terminal UI helpers.
  """

  defmacro __using__(_opts) do
    quote do
      import Exy.TUI
      alias Exy.TUI.Node
    end
  end

  defmacro defui(module, do: block) do
    quote do
      defmodule unquote(module) do
        use Exy.TUI

        Exy.TUI.__define_render__(unquote(Macro.escape(block)))
      end
    end
  end

  defmacro defui(do: block) do
    render_ast(block)
  end

  defmacro __define_render__(block) do
    render_ast(block)
  end

  defp render_ast(block) do
    quote do
      @spec render(map()) :: Node.t()
      def render(assigns \\ %{}) when is_map(assigns) do
        var!(assigns) = assigns
        unquote(block)
      end

      @spec render_lines(map(), pos_integer(), Exy.TUI.Theme.t()) :: [IO.chardata()]
      def render_lines(assigns \\ %{}, width, theme \\ Exy.TUI.Theme.default()) do
        assigns |> render() |> Exy.TUI.Node.render(width, theme)
      end
    end
  end

  defmacro vertical(do: block) do
    quote do
      Exy.TUI.Node.vertical(List.wrap(unquote(block)))
    end
  end

  defmacro assign(name) when is_atom(name) do
    quote do
      Map.fetch!(var!(assigns), unquote(name))
    end
  end

  def text(content, opts \\ []), do: Exy.TUI.Node.text(content, opts)
  def message(message), do: Exy.TUI.Node.message(message)
  def tool(tool), do: Exy.TUI.Node.tool(tool)
  def footer(footer), do: Exy.TUI.Node.footer(footer)
  def overlay(overlay), do: Exy.TUI.Node.overlay(overlay)
end
