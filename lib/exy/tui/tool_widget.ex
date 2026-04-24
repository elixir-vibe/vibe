defmodule Exy.TUI.ToolWidget do
  @moduledoc """
  Behaviour and dispatcher for built-in tool widgets.
  """

  alias Exy.TUI.{Node, Theme}

  @type tool :: map()
  @type renderer :: module()

  @callback render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]

  @renderers %{
    elixir_eval: Exy.TUI.Widgets.Tools.Eval,
    elixir_ast: Exy.TUI.Widgets.Tools.AST,
    elixir_lsp: Exy.TUI.Widgets.Tools.LSP
  }

  @spec render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(tool, width, theme) when is_map(tool) do
    tool
    |> tool_name()
    |> renderer()
    |> do_render(tool, width, theme)
  end

  @spec renderer(atom() | String.t() | nil) :: renderer()
  def renderer(name), do: Map.get(@renderers, normalize_name(name), Exy.TUI.Widgets.Tools.Generic)

  defp do_render(renderer, tool, width, theme), do: renderer.render(tool, width, theme)

  defp tool_name(tool), do: Map.get(tool, :name) || Map.get(tool, "name")

  defp normalize_name(name) when is_atom(name), do: name

  defp normalize_name(name) when is_binary(name) do
    name
    |> String.replace("-", "_")
    |> String.to_existing_atom()
  rescue
    ArgumentError -> nil
  end

  defp normalize_name(_name), do: nil

  @doc false
  def generic_lines(tool, width, theme) do
    Node.render(Node.raw(generic_title(tool, theme)), width, theme)
  end

  defp generic_title(tool, theme) do
    status = Map.get(tool, :status, :unknown)
    name = Map.get(tool, :name) || Map.get(tool, :id) || "tool"

    theme
    |> Theme.fg(:tool_title, ["◆ ", to_string(name), "  ", to_string(status)])
    |> status_bg(status, theme)
  end

  def status_bg(text, status, theme) when status in [:ok, "ok"],
    do: Theme.bg(theme, :tool_success_bg, text)

  def status_bg(text, status, theme) when status in [:error, "error"],
    do: Theme.bg(theme, :tool_error_bg, text)

  def status_bg(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)
end
