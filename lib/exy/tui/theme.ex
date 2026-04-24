defmodule Exy.TUI.Theme do
  @moduledoc """
  Semantic ANSI theme for Exy's terminal UI.

  Renderers use semantic keys instead of hardcoded colors so the same keys can
  later map to Phoenix/CSS variables.
  """

  @type color :: atom() | {byte(), byte(), byte()} | nil

  @type t :: %__MODULE__{
          name: String.t(),
          fg: %{atom() => color()},
          bg: %{atom() => color()},
          symbols: %{atom() => IO.chardata()}
        }

  defstruct name: "default", fg: %{}, bg: %{}, symbols: %{}

  @spec default() :: t()
  def default do
    %__MODULE__{
      name: "default",
      fg: %{
        accent: :cyan,
        border: :light_black,
        success: :green,
        error: :red,
        warning: :yellow,
        muted: :light_black,
        dim: :light_black,
        text: nil,
        thinking_text: :light_black,
        tool_title: :cyan,
        tool_output: nil,
        user_message_text: nil,
        assistant_message_text: nil
      },
      bg: %{
        selected_bg: {45, 45, 45},
        user_message_bg: nil,
        tool_pending_bg: {38, 38, 38},
        tool_success_bg: {22, 54, 34},
        tool_error_bg: {70, 24, 24}
      },
      symbols: %{
        separator: " • ",
        section_line: "─",
        model_icon: "◇",
        tool_icon: "◆",
        status_icon: "•",
        success_icon: "✓",
        error_icon: "×",
        dialog_top_left: "╭",
        dialog_top_right: "╮",
        dialog_bottom_left: "╰",
        dialog_bottom_right: "╯",
        dialog_vertical: "│",
        dialog_horizontal: "─"
      }
    }
  end

  @spec fg(t(), atom(), iodata()) :: String.t()
  def fg(%__MODULE__{} = theme, key, text), do: apply_color(Map.get(theme.fg, key), :fg, text)

  @spec bg(t(), atom(), iodata()) :: String.t()
  def bg(%__MODULE__{} = theme, key, text), do: apply_color(Map.get(theme.bg, key), :bg, text)

  @spec symbol(t(), atom()) :: IO.chardata()
  def symbol(%__MODULE__{} = theme, key), do: Map.fetch!(theme.symbols, key)

  @spec bold(iodata()) :: String.t()
  def bold(text), do: IO.iodata_to_binary(["\e[1m", text, reset()])

  @spec italic(iodata()) :: String.t()
  def italic(text), do: IO.iodata_to_binary(["\e[3m", text, reset()])

  @spec reset() :: String.t()
  def reset, do: IO.ANSI.reset()

  @spec strip(String.t()) :: String.t()
  def strip(text) when is_binary(text) do
    Regex.replace(~r/\e\[[0-9;]*[A-Za-z]/, text, "")
  end

  defp apply_color(nil, _target, text), do: IO.iodata_to_binary(text)

  defp apply_color({r, g, b}, :fg, text),
    do: IO.iodata_to_binary(["\e[38;2;#{r};#{g};#{b}m", text, reset()])

  defp apply_color({r, g, b}, :bg, text),
    do: IO.iodata_to_binary(["\e[48;2;#{r};#{g};#{b}m", text, reset()])

  defp apply_color(color, target, text) when is_atom(color) do
    IO.iodata_to_binary([ansi_color(color, target), text, reset()])
  end

  defp ansi_color(:black, :fg), do: IO.ANSI.black()
  defp ansi_color(:red, :fg), do: IO.ANSI.red()
  defp ansi_color(:green, :fg), do: IO.ANSI.green()
  defp ansi_color(:yellow, :fg), do: IO.ANSI.yellow()
  defp ansi_color(:blue, :fg), do: IO.ANSI.blue()
  defp ansi_color(:magenta, :fg), do: IO.ANSI.magenta()
  defp ansi_color(:cyan, :fg), do: IO.ANSI.cyan()
  defp ansi_color(:white, :fg), do: IO.ANSI.white()
  defp ansi_color(:light_black, :fg), do: IO.ANSI.light_black()
  defp ansi_color(:light_red, :fg), do: IO.ANSI.light_red()
  defp ansi_color(:light_green, :fg), do: IO.ANSI.light_green()
  defp ansi_color(:light_yellow, :fg), do: IO.ANSI.light_yellow()
  defp ansi_color(:light_blue, :fg), do: IO.ANSI.light_blue()
  defp ansi_color(:light_magenta, :fg), do: IO.ANSI.light_magenta()
  defp ansi_color(:light_cyan, :fg), do: IO.ANSI.light_cyan()
  defp ansi_color(:light_white, :fg), do: IO.ANSI.light_white()
  defp ansi_color(color, :bg), do: ansi_bg_color(color)

  defp ansi_bg_color(:black), do: IO.ANSI.black_background()
  defp ansi_bg_color(:red), do: IO.ANSI.red_background()
  defp ansi_bg_color(:green), do: IO.ANSI.green_background()
  defp ansi_bg_color(:yellow), do: IO.ANSI.yellow_background()
  defp ansi_bg_color(:blue), do: IO.ANSI.blue_background()
  defp ansi_bg_color(:magenta), do: IO.ANSI.magenta_background()
  defp ansi_bg_color(:cyan), do: IO.ANSI.cyan_background()
  defp ansi_bg_color(:white), do: IO.ANSI.white_background()
  defp ansi_bg_color(_color), do: ""
end
