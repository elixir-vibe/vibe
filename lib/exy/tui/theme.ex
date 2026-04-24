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

  @dark_fg %{
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
    assistant_message_text: nil,
    input_prompt: :cyan,
    input_text: nil,
    input_placeholder: :light_black,
    input_cursor: :black
  }

  @light_fg %{
    accent: :blue,
    border: :light_black,
    success: :green,
    error: :red,
    warning: :yellow,
    muted: :light_black,
    dim: :light_black,
    text: :black,
    thinking_text: :light_black,
    tool_title: :blue,
    tool_output: :black,
    user_message_text: :black,
    assistant_message_text: :black,
    input_prompt: :blue,
    input_text: :black,
    input_placeholder: :light_black,
    input_cursor: :white
  }

  @dark_bg %{
    selected_bg: {45, 45, 45},
    user_message_bg: nil,
    tool_pending_bg: {38, 38, 38},
    tool_success_bg: {22, 54, 34},
    tool_error_bg: {70, 24, 24},
    input_bg: {24, 24, 24},
    input_cursor_bg: :cyan
  }

  @light_bg %{
    selected_bg: {230, 230, 230},
    user_message_bg: nil,
    tool_pending_bg: {238, 238, 238},
    tool_success_bg: {218, 245, 226},
    tool_error_bg: {255, 224, 224},
    input_bg: {245, 245, 245},
    input_cursor_bg: :blue
  }

  @symbols %{
    separator: " • ",
    section_line: "─",
    model_icon: "◇",
    tool_icon: "◆",
    status_icon: "•",
    running_icon: "…",
    success_icon: "✓",
    error_icon: "×",
    warning_icon: "!",
    input_prompt: "›",
    input_cursor: " ",
    dialog_top_left: "╭",
    dialog_top_right: "╮",
    dialog_bottom_left: "╰",
    dialog_bottom_right: "╯",
    dialog_vertical: "│",
    dialog_horizontal: "─"
  }

  @spec default() :: t()
  def default, do: dark()

  @spec dark() :: t()
  def dark, do: %__MODULE__{name: "dark", fg: @dark_fg, bg: @dark_bg, symbols: @symbols}

  @spec light() :: t()
  def light, do: %__MODULE__{name: "light", fg: @light_fg, bg: @light_bg, symbols: @symbols}

  @spec named(atom() | String.t() | nil) :: t()
  def named(nil), do: default()
  def named(:default), do: default()
  def named(:dark), do: dark()
  def named(:light), do: light()
  def named("default"), do: default()
  def named("dark"), do: dark()
  def named("light"), do: light()
  def named(_name), do: default()

  @spec fg(t(), atom(), iodata()) :: IO.chardata()
  def fg(%__MODULE__{} = theme, key, text), do: apply_color(Map.get(theme.fg, key), :fg, text)

  @spec bg(t(), atom(), iodata()) :: IO.chardata()
  def bg(%__MODULE__{} = theme, key, text), do: apply_color(Map.get(theme.bg, key), :bg, text)

  @spec symbol(t(), atom()) :: IO.chardata()
  def symbol(%__MODULE__{} = theme, key), do: Map.fetch!(theme.symbols, key)

  @spec bold(iodata()) :: IO.chardata()
  def bold(text), do: ansi([:bright, text])

  @spec italic(iodata()) :: IO.chardata()
  def italic(text), do: ansi([:italic, text])

  @spec reset() :: String.t()
  def reset, do: IO.ANSI.reset()

  @spec strip(IO.chardata()) :: String.t()
  def strip(text) do
    text
    |> IO.iodata_to_binary()
    |> then(&Regex.replace(~r/\e\[[0-9;]*[A-Za-z]/, &1, ""))
  end

  defp apply_color(nil, _target, text), do: text

  defp apply_color({r, g, b}, :fg, text),
    do: ansi([IO.ANSI.color(cube(r), cube(g), cube(b)), text, :reset])

  defp apply_color({r, g, b}, :bg, text),
    do: ansi([IO.ANSI.color_background(cube(r), cube(g), cube(b)), text, :reset])

  defp apply_color(color, target, text) when is_atom(color) do
    ansi([ansi_color(color, target), text, :reset])
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

  defp cube(channel), do: channel |> Kernel./(255) |> Kernel.*(5) |> round() |> min(5) |> max(0)

  defp ansi(format), do: IO.ANSI.format(format, true)
end
