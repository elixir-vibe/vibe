defmodule Exy.TUI.ToolWidget do
  @moduledoc """
  Behaviour and dispatcher for built-in tool widgets.
  """

  alias Exy.TUI.{DSL, Theme, Widget}

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

  @spec title(tool(), Theme.t(), keyword()) :: IO.chardata()
  def title(tool, theme, opts \\ []) do
    name = opts[:name] || tool_name(tool) || "tool"
    action = opts[:action]
    summary = opts[:summary]
    status = status(tool)

    text = [
      Theme.symbol(theme, :tool_icon),
      " ",
      to_string(name),
      if(action in [nil, ""], do: "", else: [" ", Theme.fg(theme, :muted, action)]),
      if(summary in [nil, ""],
        do: "",
        else: [Theme.symbol(theme, :separator), Theme.fg(theme, :dim, summary)]
      ),
      "  ",
      status_icon(status, theme),
      " ",
      to_string(status)
    ]

    theme |> Theme.fg(:tool_title, text) |> status_bg(status, theme)
  end

  @doc false
  def generic_lines(tool, width, theme) do
    Widget.render(DSL.raw(title(tool, theme, summary: compact_summary(tool))), width, theme)
  end

  def compact_summary(tool) do
    cond do
      args = Map.get(tool, :args) || Map.get(tool, "args") -> summarize_value(args, 80)
      output = Map.get(tool, :output) || Map.get(tool, :result) -> summarize_value(output, 80)
      true -> nil
    end
  end

  def summarize_value(value, limit) when is_binary(value) do
    value |> String.replace("\n", " ") |> String.slice(0, limit)
  end

  def summarize_value(value, limit) do
    value |> inspect(limit: 8) |> String.replace("\n", " ") |> String.slice(0, limit)
  end

  def status_bg(text, status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.bg(theme, :tool_success_bg, text)

  def status_bg(text, status, theme) when status in [:error, "error"],
    do: Theme.bg(theme, :tool_error_bg, text)

  def status_bg(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)

  def status(tool), do: tool |> Map.get(:status, :running) |> normalize_status()

  def status_icon(status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.symbol(theme, :success_icon)

  def status_icon(status, theme) when status in [:error, "error"],
    do: Theme.symbol(theme, :error_icon)

  def status_icon(_status, theme), do: Theme.symbol(theme, :running_icon)

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

  defp normalize_status(:success), do: :ok
  defp normalize_status("success"), do: :ok
  defp normalize_status(status), do: status
end
