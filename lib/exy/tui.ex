defmodule Exy.TUI do
  @moduledoc """
  Declarative terminal UI helpers.
  """

  defmacro __using__(_opts) do
    quote do
      import Exy.TUI
      alias Exy.TUI.{DSL, Node}
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
      def render(assigns \\ %{}) when is_map(assigns) do
        var!(assigns) = assigns
        unquote(block)
      end

      @spec render_lines(map(), pos_integer(), Exy.TUI.Theme.t()) :: [IO.chardata()]
      def render_lines(assigns \\ %{}, width, theme \\ Exy.TUI.Theme.default()) do
        assigns |> render() |> Exy.TUI.Widget.render(width, theme)
      end
    end
  end

  defmacro vertical(do: block) do
    quote do
      Exy.TUI.DSL.vertical(List.wrap(unquote(block)))
    end
  end

  defmacro assign(name) when is_atom(name) do
    quote do
      Map.fetch!(var!(assigns), unquote(name))
    end
  end

  def horizontal(children), do: Exy.TUI.DSL.horizontal(children)
  def raw(content), do: Exy.TUI.DSL.raw(content)
  def spacer(lines \\ 1), do: Exy.TUI.DSL.spacer(lines)
  def text(content, opts \\ []), do: Exy.TUI.DSL.text(content, opts)
  def truncate(content, opts \\ []), do: Exy.TUI.DSL.truncate(content, opts)
  def message(message), do: Exy.TUI.DSL.message(message)
  def tool(tool), do: Exy.TUI.DSL.tool(tool)
  def footer(footer), do: Exy.TUI.DSL.footer(footer)
  def overlay(overlay), do: Exy.TUI.DSL.overlay(overlay)
  def section(title, children \\ []), do: Exy.TUI.DSL.section(title, children)
  def box(title \\ nil, children, opts \\ []), do: Exy.TUI.DSL.box(title, children, opts)
  def padding(children, opts \\ []), do: Exy.TUI.DSL.padding(children, opts)
  def status(props), do: Exy.TUI.DSL.status(props)
  def model_info(props), do: Exy.TUI.DSL.model_info(props)
  def dialog(title, children, opts \\ []), do: Exy.TUI.DSL.dialog(title, children, opts)
  def diff(props), do: Exy.TUI.DSL.diff(props)
end
