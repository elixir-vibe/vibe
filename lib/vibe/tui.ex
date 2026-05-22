defmodule Vibe.TUI do
  @moduledoc """
  Declarative terminal UI helpers and constructors for Vibe's TUI node tree.
  """

  alias Vibe.TUI.{Node}
  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget
  alias Vibe.UI.Autocomplete
  alias Vibe.UI.Block.{NotificationList, PluginWidget}

  @type child :: Node.t() | IO.chardata()

  defmacro __using__(_opts) do
    quote do
      import Vibe.TUI
      alias Vibe.TUI.{Node}
      alias Vibe.Terminal.{Theme}
      alias Vibe.TUI.Widget
    end
  end

  defmacro defui(module, do: block) do
    quote do
      defmodule unquote(module) do
        use Vibe.TUI

        Vibe.TUI.__define_render__(unquote(Macro.escape(block)))
      end
    end
  end

  defmacro defui(do: block), do: render_ast(block)

  defmacro __define_render__(block), do: render_ast(block)

  defp render_ast(block) do
    quote do
      def render(assigns \\ %{}) when is_map(assigns) do
        var!(assigns) = assigns
        unquote(block)
      end

      @spec render_lines(map(), pos_integer(), Theme.t()) :: [IO.chardata()]
      def render_lines(assigns \\ %{}, width, theme \\ Theme.default()) do
        assigns |> render() |> Widget.render(width, theme)
      end
    end
  end

  defmacro assign(name) when is_atom(name) do
    quote do
      Map.fetch!(var!(assigns), unquote(name))
    end
  end

  @spec vertical([child()]) :: Node.t()
  def vertical(children), do: node(:vertical, %{}, List.wrap(children))

  @spec horizontal([child()]) :: Node.t()
  def horizontal(children), do: node(:horizontal, %{}, List.wrap(children))

  @spec raw(IO.chardata()) :: Node.t()
  def raw(content), do: node(:raw, %{}, [content])

  @spec spacer(non_neg_integer()) :: Node.t()
  def spacer(lines \\ 1), do: node(:spacer, %{lines: lines})

  @spec text(IO.chardata(), keyword() | map()) :: Node.t()
  def text(content, opts \\ []), do: node(:text, Map.new(opts), [content])

  @spec markdown(IO.chardata(), keyword() | map()) :: Node.t()
  def markdown(content, opts \\ []), do: node(:markdown, Map.new(opts), [content])

  @spec footer(map() | struct()) :: Node.t()
  def footer(footer), do: node(:footer, to_props(footer))

  @spec message(map() | struct()) :: Node.t()
  def message(message), do: node(:message, to_props(message))

  @spec loader(keyword() | map()) :: Node.t()
  def loader(props \\ []), do: node(:loader, Map.new(props))

  @spec tool(map() | struct()) :: Node.t()
  def tool(tool), do: node(:tool, to_props(tool))

  @spec overlay(map() | struct()) :: Node.t()
  def overlay(overlay), do: node(:overlay, to_props(overlay))

  @spec section(IO.chardata(), [child()]) :: Node.t()
  def section(title, children \\ []), do: node(:section, %{title: title}, List.wrap(children))

  @spec box(IO.chardata() | nil, [child()], keyword() | map()) :: Node.t()
  def box(title \\ nil, children, opts \\ []) do
    node(:box, Map.put(Map.new(opts), :title, title), List.wrap(children))
  end

  @spec padding([child()], keyword() | map()) :: Node.t()
  def padding(children, opts \\ []), do: node(:padding, Map.new(opts), List.wrap(children))

  @spec truncate(IO.chardata(), keyword() | map()) :: Node.t()
  def truncate(content, opts \\ []), do: node(:truncate, Map.new(opts), [content])

  @spec status(keyword() | map()) :: Node.t()
  def status(props), do: node(:status, Map.new(props))

  @spec model_info(keyword() | map()) :: Node.t()
  def model_info(props), do: node(:model_info, Map.new(props))

  @spec input(keyword() | map()) :: Node.t()
  def input(props), do: node(:input, Map.new(props))

  @spec textarea(keyword() | map()) :: Node.t()
  def textarea(props), do: node(:textarea, Map.new(props))

  @spec select_list(keyword() | map()) :: Node.t()
  def select_list(props), do: node(:select_list, Map.new(props))

  @spec autocomplete(keyword() | map() | Autocomplete.t()) :: Node.t()
  def autocomplete(%Autocomplete{} = autocomplete),
    do: autocomplete(Map.from_struct(autocomplete))

  def autocomplete(props), do: node(:autocomplete, Map.new(props))

  @spec notifications(keyword() | map() | NotificationList.t()) :: Node.t()
  def notifications(%NotificationList{items: items}), do: notifications(items: items)
  def notifications(props), do: node(:notifications, Map.new(props))

  @spec plugin_widget(keyword() | map() | PluginWidget.t()) :: Node.t()
  def plugin_widget(%PluginWidget{} = widget),
    do: plugin_widget(Map.from_struct(widget))

  def plugin_widget(props), do: node(:plugin_widget, Map.new(props))

  @spec dialog(IO.chardata(), [child()], keyword() | map()) :: Node.t()
  def dialog(title, children, opts \\ []) do
    node(:dialog, Map.put(Map.new(opts), :title, title), List.wrap(children))
  end

  @spec confirmation(keyword() | map()) :: Node.t()
  def confirmation(props), do: node(:confirmation, Map.new(props))

  @spec diff(keyword() | map()) :: Node.t()
  def diff(props), do: node(:diff, Map.new(props))

  @spec node(atom(), map(), [child()]) :: Node.t()
  def node(type, props \\ %{}, children \\ []) when is_atom(type) and is_map(props) do
    %Node{type: type, props: props, children: children}
  end

  defp to_props(%_{} = struct), do: Map.from_struct(struct)
  defp to_props(map) when is_map(map), do: map
end
