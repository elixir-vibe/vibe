defmodule Mix.Tasks.Vibe.Tui.Storybook do
  @shortdoc "Render Vibe TUI storybook stories"

  @moduledoc """
  Renders Vibe's TUI storybook.

      mix vibe.tui.storybook
      mix vibe.tui.storybook --story tool_eval_ok --width 100
      mix vibe.tui.storybook --plain
      mix vibe.tui.storybook --theme light

  """

  use Mix.Task

  alias Vibe.TUI.Storybook

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [story: :string, width: :integer, plain: :boolean, theme: :string],
        aliases: [s: :story, w: :width]
      )

    width = opts[:width] || terminal_width()
    theme = Vibe.TUI.Theme.named(opts[:theme])

    stories =
      if opts[:story],
        do: [story!(opts[:story])],
        else: Storybook.stories()

    Enum.each(stories, fn story ->
      IO.puts("\n#{story}\n" <> String.duplicate("=", String.length(to_string(story))))

      lines =
        if opts[:plain] do
          Storybook.render_plain(story, width: width, theme: theme)
        else
          Storybook.render(story, width: width, theme: theme)
        end

      Enum.each(lines, &IO.puts(IO.iodata_to_binary(&1)))
    end)
  end

  defp story!(name) do
    Enum.find(Storybook.stories(), &(to_string(&1) == name)) ||
      Mix.raise("unknown story #{inspect(name)}")
  end

  defp terminal_width do
    case :io.columns() do
      {:ok, columns} -> columns
      _ -> 100
    end
  end
end
