Mix.Task.run("app.start")

alias Exy.TUI.{DSL, Lines, Storybook, Theme, Widget}

width =
  System.argv()
  |> Enum.chunk_every(2, 1, :discard)
  |> Enum.find_value(100, fn
    ["--width", value] -> String.to_integer(value)
    _other -> nil
  end)

base_dark = Theme.dark()
base_light = Theme.light()

put_colors = fn theme, fg, bg ->
  %Theme{theme | fg: Map.merge(theme.fg, fg), bg: Map.merge(theme.bg, bg)}
end

crush_ish_dark =
  put_colors.(
    %Theme{base_dark | name: "crush-ish-dark"},
    %{
      accent: {178, 148, 187},
      border: {74, 78, 88},
      success: {126, 170, 115},
      error: {204, 102, 102},
      warning: {240, 198, 116},
      muted: {156, 160, 168},
      dim: {100, 104, 112},
      text: {220, 224, 230},
      thinking_text: {150, 154, 164},
      tool_output: {150, 154, 164},
      user_message_text: {232, 232, 236},
      assistant_message_text: {220, 224, 230},
      input_prompt: {126, 170, 115},
      input_text: {232, 232, 236},
      input_placeholder: {128, 132, 140},
      input_cursor: :black
    },
    %{
      selected_bg: {60, 54, 72},
      user_message_bg: {37, 39, 47},
      assistant_message_bg: {27, 29, 34},
      tool_pending_bg: {34, 36, 42},
      tool_success_bg: {35, 44, 34},
      tool_error_bg: {48, 35, 35},
      input_bg: {31, 33, 39},
      input_cursor_bg: {178, 148, 187}
    }
  )

crush_ish_light =
  put_colors.(
    %Theme{base_light | name: "crush-ish-light"},
    %{
      accent: {126, 92, 145},
      border: {190, 184, 198},
      success: {86, 132, 78},
      error: {176, 78, 78},
      warning: {156, 112, 42},
      muted: {92, 96, 108},
      dim: {128, 132, 142},
      text: {34, 36, 44},
      thinking_text: {100, 104, 116},
      tool_title: {34, 36, 44},
      tool_output: {92, 96, 108},
      user_message_text: {34, 36, 44},
      assistant_message_text: {34, 36, 44},
      input_prompt: {86, 132, 78},
      input_text: {34, 36, 44},
      input_placeholder: {128, 132, 142},
      input_cursor: :white
    },
    %{
      selected_bg: {230, 224, 238},
      user_message_bg: {244, 242, 247},
      assistant_message_bg: {250, 250, 252},
      tool_pending_bg: {244, 244, 248},
      tool_success_bg: {238, 246, 236},
      tool_error_bg: {248, 238, 238},
      input_bg: {247, 247, 250},
      input_cursor_bg: {126, 92, 145}
    }
  )

candidates = [
  {"current-dark", "Current Exy dark palette, useful as the baseline to beat.", base_dark},
  {"current-light",
   "Current Exy light palette; included because it currently feels good even on dark terminals.",
   base_light},
  {"neutral-dark",
   "Neutral-first dark: assistant reading surface is calm, color reserved for prompt/status.",
   put_colors.(
     %Theme{base_dark | name: "neutral-dark"},
     %{
       accent: {110, 190, 190},
       border: {82, 88, 105},
       success: {120, 190, 135},
       error: {220, 105, 105},
       warning: {215, 170, 85},
       muted: {145, 150, 165},
       dim: {92, 96, 108},
       text: {218, 222, 232},
       thinking_text: {135, 130, 165},
       tool_output: {150, 155, 168},
       user_message_text: {230, 233, 240},
       assistant_message_text: {218, 222, 232},
       input_prompt: {110, 190, 190},
       input_text: {230, 233, 240},
       input_placeholder: {120, 126, 140},
       input_cursor: :black
     },
     %{
       selected_bg: {48, 54, 72},
       user_message_bg: {34, 39, 52},
       assistant_message_bg: {28, 31, 38},
       tool_pending_bg: {34, 36, 45},
       tool_success_bg: {32, 43, 35},
       tool_error_bg: {48, 34, 36},
       input_bg: {30, 33, 43},
       input_cursor_bg: {110, 190, 190}
     }
   )},
  {"pi-ish",
   "Pi-like: slate user card, assistant nearly plain, cyan/teal accent on small surfaces.",
   put_colors.(
     %Theme{base_dark | name: "pi-ish"},
     %{
       accent: {138, 190, 183},
       border: {80, 86, 104},
       success: {181, 189, 104},
       error: {204, 102, 102},
       warning: {230, 190, 90},
       muted: {145, 145, 150},
       dim: {102, 102, 102},
       text: {220, 220, 220},
       thinking_text: {150, 150, 155},
       tool_output: {150, 150, 150},
       user_message_text: {230, 230, 235},
       assistant_message_text: {220, 220, 220},
       input_prompt: {138, 190, 183},
       input_text: {230, 230, 235},
       input_placeholder: {128, 128, 135},
       input_cursor: :black
     },
     %{
       selected_bg: {58, 58, 74},
       user_message_bg: {52, 53, 65},
       assistant_message_bg: {28, 29, 36},
       tool_pending_bg: {40, 40, 50},
       tool_success_bg: {40, 50, 40},
       tool_error_bg: {60, 40, 40},
       input_bg: {34, 35, 44},
       input_cursor_bg: {138, 190, 183}
     }
   )},
  {"crush-ish-dark",
   "Crush-inspired dark: charcoal neutrals, purple focus, green only for success/prompt.",
   crush_ish_dark},
  {"crush-ish-light",
   "Crush-inspired light: off-white surfaces, muted purple focus, green only for success/prompt.",
   crush_ish_light},
  {"pastel-dark",
   "Keeps the pleasant card contrast of the light theme but darkens the foreground system.",
   put_colors.(
     %Theme{base_dark | name: "pastel-dark"},
     %{
       accent: {95, 170, 205},
       border: {95, 120, 175},
       success: {95, 165, 115},
       error: {210, 105, 105},
       warning: {205, 145, 60},
       muted: {150, 150, 160},
       dim: {105, 108, 118},
       text: {225, 228, 235},
       thinking_text: {150, 130, 200},
       tool_output: {150, 150, 160},
       user_message_text: {28, 32, 42},
       assistant_message_text: {28, 38, 32},
       input_prompt: {95, 170, 205},
       input_text: {225, 228, 235},
       input_placeholder: {128, 132, 142},
       input_cursor: :black
     },
     %{
       selected_bg: {70, 76, 96},
       user_message_bg: {190, 210, 235},
       assistant_message_bg: {194, 222, 202},
       tool_pending_bg: {46, 48, 58},
       tool_success_bg: {42, 55, 43},
       tool_error_bg: {58, 42, 42},
       input_bg: {34, 36, 46},
       input_cursor_bg: {95, 170, 205}
     }
   )}
]

swatch = fn theme, key ->
  [Theme.bg(theme, key, "    "), " ", Atom.to_string(key)]
end

sample_lines = fn theme ->
  swatches =
    DSL.vertical([
      DSL.raw(swatch.(theme, :user_message_bg)),
      DSL.raw(swatch.(theme, :assistant_message_bg)),
      DSL.raw(swatch.(theme, :input_bg)),
      DSL.raw(swatch.(theme, :selected_bg)),
      DSL.raw(swatch.(theme, :tool_pending_bg)),
      DSL.raw(swatch.(theme, :tool_success_bg)),
      DSL.raw(swatch.(theme, :tool_error_bg))
    ])
    |> Widget.render(width, theme)

  [
    Storybook.render(:chat_basic, width: width, theme: theme),
    [""],
    Storybook.render(:markdown_rich, width: width, theme: theme),
    [""],
    Storybook.render(:tool_eval_ok, width: width, theme: theme),
    [""],
    Storybook.render(:footer_plugin_status, width: width, theme: theme),
    [""],
    Storybook.render(:input, width: width, theme: theme),
    [""],
    swatches
  ]
  |> Enum.reduce([], &Lines.join(&2, &1))
end

IO.puts("Exy theme candidates")
IO.puts("Run with: mix run scripts/theme_preview.exs -- --width 120")

IO.puts(
  "Look for: readable assistant text, subtle full-width cards, calm footer, visible prompt cursor."
)

IO.puts("")

Enum.each(candidates, fn {name, rationale, theme} ->
  IO.puts(IO.ANSI.format([:bright, "=== ", name, " ==="], true))
  IO.puts(rationale)
  IO.puts("")

  theme
  |> sample_lines.()
  |> Enum.each(fn line -> line |> IO.iodata_to_binary() |> IO.puts() end)

  IO.puts("")
end)
