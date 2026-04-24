defmodule Exy.TUI.DSL do
  @moduledoc """
  Constructors for Exy's declarative TUI node tree.
  """

  alias Exy.TUI.Node

  @type child :: Node.t() | IO.chardata()

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

  @spec notifications(keyword() | map()) :: Node.t()
  def notifications(props), do: node(:notifications, Map.new(props))

  @spec dialog(IO.chardata(), [child()], keyword() | map()) :: Node.t()
  def dialog(title, children, opts \\ []) do
    node(:dialog, Map.put(Map.new(opts), :title, title), List.wrap(children))
  end

  @spec diff(keyword() | map()) :: Node.t()
  def diff(props), do: node(:diff, Map.new(props))

  @spec node(atom(), map(), [child()]) :: Node.t()
  def node(type, props \\ %{}, children \\ []) when is_atom(type) and is_map(props) do
    %Node{type: type, props: props, children: children}
  end

  defp to_props(%_{} = struct), do: Map.from_struct(struct)
  defp to_props(map) when is_map(map), do: map
end
